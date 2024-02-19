TODO: add deployment instructions

run script on Windows:
```
az vm run-command create --name myRunCommand --vm-name win-2022-test-2 -g test --script @reconfig-win.ps1
```

run script on Ubuntu:
```
az vm run-command invoke -g test -n ubuntu-2 --command-id RunShellScript --scripts @reconfig-ubuntu.sh
```
