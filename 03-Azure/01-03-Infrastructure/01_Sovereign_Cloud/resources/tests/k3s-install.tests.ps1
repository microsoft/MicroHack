BeforeAll {
    $template = Get-Content "$PSScriptRoot/../../labautomation/sovereign-lab.bicep" -Raw
    $match = [regex]::Match($template, "(?s)var k3sInstallScript = '''\r?\n(.*?)\r?\n'''")
    if (-not $match.Success) { throw 'K3s extension script not found.' }
    $installScript = $match.Groups[1].Value
    $fixture = @'
export TEST_ROOT="$1"
export SCENARIO="$2"
record() { printf '%s\n' "$*" >>"$TEST_ROOT/calls"; }
count_call() {
  local count=0
  if [ -f "$TEST_ROOT/count-$1" ]; then read -r count <"$TEST_ROOT/count-$1"; fi
  count=$((count + 1))
  printf '%s\n' "$count" >"$TEST_ROOT/count-$1"
  printf '%s' "$count"
}
command() {
  if [ "$1" = -v ] && [ "$2" = k3s ]; then
    [[ "$SCENARIO" = existing || "$SCENARIO" = partial ]]
  else
    builtin command "$@"
  fi
}
install() { record install; }
mktemp() { builtin command mktemp "$TEST_ROOT/installer.XXXXXX"; }
sleep() { record "sleep $*"; }
timeout() {
  record "timeout $*"
  shift 2
  if [ "$SCENARIO" = timeout ] && [ "$1" = sh ]; then return 124; fi
  "$@"
}
curl() {
  record "curl $*"
  if [[ "$*" = *update.k3s.io* ]]; then
    local count
    count=$(count_call lookup)
    if [ "$SCENARIO" = lookup-failure ]; then return 22; fi
    if [ "$SCENARIO" = lookup-retry ] && [ "$count" -lt 3 ]; then return 28; fi
    if [ "$SCENARIO" = invalid-release ]; then
      printf 'https://example.invalid/stable'
    else
      printf 'https://github.com/k3s-io/k3s/releases/tag/v1.37.2+k3s1'
    fi
  else
    local count
    count=$(count_call installer)
    if [ "$SCENARIO" = installer-failure ]; then return 22; fi
    if [ "$SCENARIO" = installer-retry ] && [ "$count" -lt 3 ]; then return 28; fi
  fi
}
sh() {
  local count
  count=$(count_call installation)
  record "installation $count version=$INSTALL_K3S_VERSION"
  if [ "$SCENARIO" = persistent ]; then return 1; fi
  if [[ "$SCENARIO" = hash-retry || "$SCENARIO" = binary-retry ]] && [ "$count" -lt 3 ]; then
    echo "ERROR: $SCENARIO download failed" >&2
    return 1
  fi
}
systemctl() {
  record "systemctl $*"
  if [ "$1" = cat ]; then [ "$SCENARIO" = existing ]; return; fi
  if [ "$1" = is-active ] && [ "$SCENARIO" = inactive ]; then return 3; fi
  return 0
}
k3s() {
  record "k3s $*"
  if [ "$2" = get ]; then
    local count
    count=$(count_call registration)
    if [ "$SCENARIO" = no-node ]; then return 0; fi
    if [ "$SCENARIO" = api-failure ]; then echo 'API unavailable' >&2; return 1; fi
    if [ "$SCENARIO" = delayed-node ] && [ "$count" -lt 3 ]; then return 0; fi
    echo node/test-node
  elif [ "$SCENARIO" = not-ready ]; then
    echo 'ERROR: Node readiness timed out' >&2
    return 1
  fi
}
'@
    function Invoke-K3sFixture {
        param([string]$Scenario)
        $directory = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory $directory
        $scriptPath = Join-Path $directory 'run.sh'
        $source = $installScript.Replace('/etc/rancher/k3s/config.yaml', "$directory/config.yaml")
        [IO.File]::WriteAllText($scriptPath, ($fixture + "`n" + $source).Replace("`r`n", "`n"))
        $output = & bash $scriptPath $directory $Scenario 2>&1
        $exitCode = $LASTEXITCODE
        [pscustomobject]@{
            ExitCode = $exitCode
            Output = $output -join "`n"
            Calls = @(Get-Content "$directory/calls")
            Installers = @(Get-ChildItem "$directory/installer.*")
        }
    }
}

Describe 'K3s extension bounded recovery' -Skip:(-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    It 'has valid Bash syntax' {
        $path = Join-Path $TestDrive 'syntax.sh'
        [IO.File]::WriteAllText($path, $installScript)
        & bash -n $path
        $LASTEXITCODE | Should -Be 0
    }
    It 'installs once and verifies node readiness' {
        $result = Invoke-K3sFixture success
        $result.ExitCode | Should -Be 0
        @($result.Calls -like 'installation *').Count | Should -Be 1
        @($result.Calls -like 'sleep *').Count | Should -Be 0
        @($result.Calls -like 'timeout --kill-after=15s 600s sh *').Count | Should -Be 1
        $result.Calls | Should -Contain 'timeout --kill-after=15s 150s k3s kubectl wait --for=condition=Ready nodes --all --timeout=120s --request-timeout=10s'
        $result.Installers.Count | Should -Be 0
    }
    It 'retries <Scenario> with fixed version and 20/40-second backoff' -TestCases @(
        @{ Scenario = 'hash-retry' }
        @{ Scenario = 'binary-retry' }
    ) {
        param($Scenario)
        $result = Invoke-K3sFixture $Scenario
        $result.ExitCode | Should -Be 0
        @($result.Calls -like 'curl *update.k3s.io*').Count | Should -Be 1
        @($result.Calls -like 'installation *version=v1.37.2+k3s1').Count | Should -Be 3
        ($result.Calls -like 'sleep *') -join ',' | Should -Be 'sleep 20,sleep 40'
        $result.Installers.Count | Should -Be 0
    }
    It 'bounds <Scenario> failures and never reports readiness' -TestCases @(
        @{ Scenario = 'persistent'; Code = 1 }
        @{ Scenario = 'timeout'; Code = 124 }
        @{ Scenario = 'lookup-failure'; Code = 22 }
        @{ Scenario = 'installer-failure'; Code = 22 }
    ) {
        param($Scenario, $Code)
        $result = Invoke-K3sFixture $Scenario
        $result.ExitCode | Should -Be $Code
        ($result.Calls -like 'sleep *') -join ',' | Should -Be 'sleep 20,sleep 40'
        $result.Output | Should -Match "failed \(exit $Code, attempt 3/3\)"
        @($result.Calls -like 'k3s *').Count | Should -Be 0
        $result.Installers.Count | Should -Be 0
    }
    It 'recovers <Scenario> before installing' -TestCases @(
        @{ Scenario = 'lookup-retry' }
        @{ Scenario = 'installer-retry' }
    ) {
        param($Scenario)
        $result = Invoke-K3sFixture $Scenario
        $result.ExitCode | Should -Be 0
        ($result.Calls -like 'sleep *') -join ',' | Should -Be 'sleep 20,sleep 40'
        @($result.Calls -like 'installation *').Count | Should -Be 1
    }
    It 'rejects malformed release selection without invoking the installer' {
        $result = Invoke-K3sFixture invalid-release
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'did not resolve to a valid K3s release'
        @($result.Calls -like 'installation *').Count | Should -Be 0
    }
    It 'preserves existing-service behavior without downloading again' {
        $result = Invoke-K3sFixture existing
        $result.ExitCode | Should -Be 0
        @($result.Calls -like 'curl *').Count | Should -Be 0
        $result.Calls | Should -Contain 'systemctl enable --now k3s'
        $result.Calls | Should -Contain 'systemctl restart k3s'
    }
    It 'repairs a partial install with a binary but no service' {
        $result = Invoke-K3sFixture partial
        $result.ExitCode | Should -Be 0
        @($result.Calls -like 'installation *').Count | Should -Be 1
    }
    It 'waits for registration before checking readiness' {
        $result = Invoke-K3sFixture delayed-node
        $result.ExitCode | Should -Be 0
        ($result.Calls -like 'sleep *') -join ',' | Should -Be 'sleep 5,sleep 5'
        @($result.Calls -like 'k3s kubectl get *').Count | Should -Be 3
        @($result.Calls -like 'k3s kubectl wait *').Count | Should -Be 1
    }
    It 'fails explicitly on <Scenario> after bounded registration checks' -TestCases @(
        @{ Scenario = 'no-node' }
        @{ Scenario = 'api-failure' }
    ) {
        param($Scenario)
        $result = Invoke-K3sFixture $Scenario
        $result.ExitCode | Should -Be 1
        @($result.Calls -like 'k3s kubectl get *').Count | Should -Be 24
        @($result.Calls -like 'k3s kubectl wait *').Count | Should -Be 0
        $result.Output | Should -Match 'No K3s node registered'
    }
    It 'does not reinstall to mask <Scenario>' -TestCases @(
        @{ Scenario = 'inactive'; Code = 1 }
        @{ Scenario = 'not-ready'; Code = 1 }
    ) {
        param($Scenario, $Code)
        $result = Invoke-K3sFixture $Scenario
        $result.ExitCode | Should -Be $Code
        @($result.Calls -like 'installation *').Count | Should -Be 1
    }
}
