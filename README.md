# Quarkus Helm - Flyway init task as Helm hook

[![CI](https://github.com/matheusandre1/quarkus-helm-flyway-hook-demo/actions/workflows/ci.yml/badge.svg)](https://github.com/matheusandre1/quarkus-helm-flyway-hook-demo/actions/workflows/ci.yml)

Reproducer and test project for [quarkiverse/quarkus-helm#451](https://github.com/quarkiverse/quarkus-helm/issues/451).

When using Flyway, Quarkus generates a Kubernetes Job to run the migrations (`<app>-flyway-init`). Since Jobs are immutable, `helm upgrade` fails as soon as the Job changes, for example, when a new application version changes the image tag:

```
Error: UPGRADE FAILED: ... Job.batch "flyway-hook-demo-flyway-init" is invalid: [..., spec.template: ...: field is immutable]
```

The fix adds the property `quarkus.helm.init-task-hook.enabled`, which annotates the init task Jobs as Helm hooks:

```yaml
metadata:
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation
```

So, Helm deletes the previous Job and creates the new one on every install/upgrade.

## Requirements

- Java 21
- [Minikube](https://minikube.sigs.k8s.io/), `kubectl` and `helm`
- The Quarkus Helm extension with the fix installed in the local Maven repository (`1.4.4-SNAPSHOT`):

```shell
git clone -b issue451 https://github.com/matheusandre1/quarkus-helm.git
cd quarkus-helm
mvn install -DskipTests -pl deployment -am
```

## CI

The [CI workflow](.github/workflows/ci.yml) builds the Quarkus Helm extension from the branch with the fix, and runs `test.sh` in Minikube with and without the fix. The repository and the branch of the extension can be changed when running the workflow manually.

## Running the test

The script `test.sh` starts Minikube (if needed), deploys a PostgreSQL database, installs the Helm chart with the version `1.0.0`, and then upgrades it with the version `1.0.1` (so the Job image changes). After each step, it checks that the migrations were executed calling the `/hello` endpoint.

With the fix (`quarkus.helm.init-task-hook.enabled=true`), the upgrade succeeds:

```shell
./test.sh
```

```
### Installing version 1.0.0 (init-task-hook.enabled=true)
Job image: docker.io/demo/flyway-hook-demo:1.0.0
GET /hello: Hello from the Flyway migration!
### Upgrading to version 1.0.1 (init-task-hook.enabled=true)
Job image: docker.io/demo/flyway-hook-demo:1.0.1
GET /hello: Hello from the Flyway migration!
### Upgrade succeeded
```

Without the fix (`quarkus.helm.init-task-hook.enabled=false`), the upgrade fails because the Job is immutable:

```shell
./test.sh false
```

## Notes

- `quarkus.flyway.migrate-at-start=true` is required, so the init task Job runs the migrations.
- `quarkus.kubernetes.add-version-to-label-selectors=false` is required too. Otherwise, the Deployment selector includes the application version, and `helm upgrade` fails because the selector is immutable as well.
- If you use `helm install --wait`, Helm waits for the Deployment to be ready before running the `post-install` hook. Since the Deployment waits for the Job to complete (init container `wait-for-flyway`), the installation hangs until the timeout:

  ```
  Error: INSTALLATION FAILED: resource Deployment/default/flyway-hook-demo not ready. status: InProgress, message: Available: 0/1
  ```
