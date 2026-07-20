---
name: java-upgrade
description: >-
  Transformation rules and verification steps for upgrading Java 8/11 +
  Spring Boot 2.x applications to Java 21 + Spring Boot 3.x.
  WHEN: upgrade Java version, migrate Spring Boot 2 to 3, javax to jakarta,
  fix CVE in Java dependencies, update Maven/Gradle build for Java 21,
  Spring Security 5 to 6 migration.
  NOT for: greenfield Java services, framework replacement rewrites
  (Struts/EJB — use dedicated migration rulebooks), infrastructure-only changes.
---

# Java 8 / Spring Boot 2.x → Java 21 / Spring Boot 3.x Upgrade Rules

## Purpose

Packages the version-step strategy, API mappings, and verification checklist for a
behavior-preserving upgrade to Java 21 + Spring Boot 3.x.

## Prerequisites

- `ASSESSMENT.md` exists and is approved.
- JDK 21 + compatible Maven installed — verify: `java -version`, `mvn -version`.

## Procedure

### Step 1 — Upgrade incrementally (never skip)

| Step | From → To | Key risk at this step |
|---|---|---|
| 1 | Java 8 → 11 | Removed JEE modules (JAXB, JAX-WS) — add explicit deps |
| 2 | Java 11 → 17 | Strong encapsulation of JDK internals (`--add-opens` smells) |
| 3 | Java 17 → 21 | Mostly safe; check agents/bytecode libs (ASM, CGLIB versions) |
| 4 | Boot 2.x → 2.7 | Deprecation cleanup before the big jump |
| 5 | Boot 2.7 → 3.x | `javax → jakarta`, Spring Security 6, Hibernate 6 |

```powershell
mvn -q clean verify   # run after EVERY step; fix before proceeding
```

### Step 2 — Apply transformation rules (Boot 2.7 → 3.x)

| Source pattern | Target pattern | Notes |
|---|---|---|
| `javax.persistence.*` / `javax.servlet.*` / `javax.validation.*` | `jakarta.*` | Also grep XML, `persistence.xml`, reflection strings |
| `WebSecurityConfigurerAdapter` | `SecurityFilterChain` bean | Spring Security 6 lambda DSL |
| `antMatchers()` | `requestMatchers()` | Security DSL rename |
| `spring.factories` (auto-config) | `AutoConfiguration.imports` | New registration file |
| `httpTrace` / deprecated actuator IDs | new actuator endpoint IDs | Check `management.endpoints` config |
| Hibernate 5 dialects/types | Hibernate 6 equivalents | ID generation defaults changed — verify sequences |
| `springfox` (Swagger) | `springdoc-openapi` | springfox is incompatible with Boot 3 |
| {{APP_SPECIFIC_RULE_1}} | {{TARGET_1}} | {{NOTE}} |
| {{APP_SPECIFIC_RULE_2}} | {{TARGET_2}} | {{NOTE}} |

### Step 3 — Verify

- [ ] `mvn clean verify` passes on JDK 21
- [ ] `grep -r "javax\." src/` returns only intentional matches (e.g. `javax.crypto`, `javax.sql` stay in the JDK)
- [ ] App starts; health endpoint returns UP
- [ ] CVE assessment clean of criticals (`appmod-java-cve-assessment`)
- [ ] No `--add-opens` workarounds left without a tracked issue

## Common Pitfalls

- ⚠️ **`javax.` survivors outside Java code** — XML configs, `import` strings in reflection, SPI files. The compiler won't save you; grep everything.
- ⚠️ **Hibernate 6 sequence allocation changes** — verify generated IDs against existing DB sequences before deploying.
- ⚠️ **Lombok/annotation processors** need versions matching the new JDK — upgrade build plugins (`maven-compiler-plugin` ≥ 3.11) first.
- ⚠️ **Trailing-slash matching** changed in Spring 6 — `/api/foo/` no longer matches `/api/foo` by default.
- ⚠️ {{APP_SPECIFIC_PITFALL}}

## References

- Spring Boot 3.x migration guide; Spring Security 6 migration guide
- OpenRewrite recipes: `org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_x`
- appmod assessment report (linked from `ASSESSMENT.md`)
