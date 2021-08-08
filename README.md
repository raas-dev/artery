# 💢

This template is for running Express powered APIs on Azure App Service with:

- Blue-green zero-downtime deployments and all environments behind Azure AD auth
- Monitoring, alerts, availability tests and logging to analytics workspace
- OpenAPI middleware validating requests and routing to (TypeScript) handlers
- Azure Pipelines for updating Azure services and releasing Docker images to ACR
- A pipeline for importing/updating the API in existing Azure API Management(s)

Principles:

- OpenAPI driven development for mocking and enforcing req and res validations
- Generate both API tests and load tests automatically based on API definition
- Minimize number of environments, internal differences, maintenance and costs
- One command deploy PaaS with connectivity, monitoring and identity services
- Create Azure DevOps project and pipelines with IAC, requiring only Azure CLI

## ⚙️ Development

Install Node.js version in `.nvmrc`, with [nvm](https://github.com/nvm-sh/nvm):

    nvm install

Install npm packages:

    npm install

### Usage

Build production `dist/`:

    npm run build

Start development server watching for changes:

    npm run dev

Run functional tests on [Jest](https://jestjs.io/):

    npm test

Run API tests on [Newman](https://github.com/postmanlabs/newman):

    npm run test:api

Generate and run [k6](https://k6.io/) load tests and the API in Docker Compose:

    npm run k6

The Docker Compose stack includes a
[Grafana dashboard](http://localhost:3000/d/k6/k6-load-testing-results)
for load test results:

![K6 load test results dashboard in Grafana](docs/grafana_k6.png)

### Metrics and logging

[Morgan](https://github.com/expressjs/morgan) is used as Express middleware for
logging HTTP requests to console.

See [localhost:8080/stats](http://localhost:8080) and login with username
and password `local` for real-time metrics by
[swagger-stats middleware](https://github.com/slanatech/swagger-stats).

![Real-time statistics for endpoints](docs/swagger_stats.png)

When [deployed to Azure](bicep/README.md) username and password are
set in the App Service app settings and generated from branch name and
commit SHA by the [Azure DevOps pipeline](devops/README.md).

In Azure, Node.js metrics are also streamed to Application Insights and logs
to Log Analytics Workspace.

### Mocking APIs

Use [Prism](https://github.com/stoplightio/prism) locally to fake APIs
defined in `openapi.yaml` but not yet implemented in Express:

    npm run prism:mock

Fake data is generated dynamically according to the `x-faker` property in the
OpenAPI definition. See [Faker.js](https://github.com/marak/Faker.js#api-methods)
for all kinds of test data it can be used generate.

To run Prism so that the already implemented endpoints are responded by Express:

    npm run prism:proxy

This launches the Prism server at [localhost:4010](http://localhost:4010)
returning mock responses for the non-implemented endpoints according to
`example`/`examples` properties in OpenAPI definition.

This is effective for all the routes which do not have handler set by the
OpenAPI properties `operationId` and `x-eov-operation-handler`, as the
Express will respond HTTP status 501 (Not Implemented) for routes that
do not have handlers implemented, causing Prism to then to mock the response.

## ✨ Contributing

[Pull requests](https://github.com/raas-dev/artery/pulls) are reviewed in
GitHub. Deploy PRs to testing requires approval from the project admin
if the person submitting the pull request is outside of the project core team.

### Changelog

Update `CHANGELOG.md` by [auto-changelog](https://github.com/CookPete/auto-changelog):

    npm run changelog

### Pre-commit

Run [ESLint](https://eslint.org/) automatically fixing issues if any:

    npm run lint:fix

Visual Studio Code is preferred as it can install the extensions defined in
`.vscode/extensions.json`. Thus linting, fixing and formatting both code and
the OpenAPI spec runs edit-time, before changes even ending up in a commit.

In addition to edit-time helpers, [Husky](https://typicode.github.io/husky/#/)
is used for running the git hooks defined in `.husky/pre-commit`, such as:

- ESLint for linting and autofixing TypeScript, configured in `.eslintrc.js`
- [Prettier](https://prettier.io/) for formatting, configured in `.prettierrc`
- [Spectral](https://stoplight.io/open-source/spectral/) for linting OpenAPI
- `npm run portman` to generate always up-to-date API tests from `openapi.yaml`

### CI/CD

[Azure DevOps](https://dev.azure.com/raas-dev/artery) has the pipelines for
building Docker images, deploying to testing-staging and rc-production in Azure,
the infra pipeline to create/update the Azure resources for those environments,
and _api-to-apim_ to import/update the API in an existing API Management service.

The pipeline stages are configured as following:

| Environment | CI  | Branch | CD  | Deployment trigger                 |
| ----------- | :-: | ------ | :-: | ---------------------------------- |
| testing     | ✔️  | `*`    | ✔️  | PRs about to be merged to `main`   |
| staging     | ✔️  | `main` |     | testing deployed + manual approval |
| rc          | ✔️  | `prod` | ✔️  | `main` merged to `prod`            |
| production  | ✔️  | `prod` |     | rc deployed + manual approval      |

Git workflow includes two persistent branches in addition to feature branches:

`main`

- has squashed merges of Pull Requests (which are created from feature branches)
- primary use is **releasing to staging**
  - release to testing happens from feature branches trigged by a created PR
  - staging deployment happens from `main` after testing has been reviewed
    - it is recommended to configure a manual approval step for going to
      staging, being usually the environment for internal demoing purposes

`prod`

- has merges from `main`
- only for **releasing to rc and prodution**
  - deployment to rc is triggered as soon as something is merged to `prod`
    - optionally, rc App Service slot can be then set to take N% of traffic
  - for going to production, it is recommended to have a manual approval step
    - this acts a heads up if there is any chance that rollback to previous
      prod may be required in case of errors
      - note that after prod deployment, the previous prod is in slot 'rc'
        - thus rollback is possibly done fastest by just swapping the slots

## 🏗️ Infrastructure

Docker images are used as the primary distribution mechanism and thus the npm
package is configured as private in `package.json`.

The Docker images can be hosted in any Docker registry and containers will
run in any system having Docker available, but Azure Container Registry and
Azure App Service are preferred as the registry and the PaaS, respectively.

### Local

Multi-staged `docker/` files are used to build the images as following:

- The first stage runs all tests before transpiling TypeScript to JavaScript.
- The second stage copies JS and installs only its production dependencies
- The final (run-time) image knows nothing about packages and has only pure JS

To build the API image locally and run the production server in container:

    docker/build_and_test_image

Or to run the API, as well as k6 and its Grafana dashboard with Docker Compose:

    docker-compose up

By default, Alpine Linux based Docker images are built, but Debian Buster
(slim) Dockerfiles are also included in `docker/` if happen to face any
[Alpine caveats](https://github.com/gliderlabs/docker-alpine/blob/master/docs/caveats.md).

Docker images are built by the CI/CD pipelines per environment and pushed to
the environment specific Azure Container Registry. When building image locally,
with `docker/build_and_test_image`, `docker/Dockerfile.alpine.prod` is used.

The difference between non-prod and prod images is that non-prod will install,
configure (according to AppService's guidelines) and start an SSH daemon which
will help debugging over the wire in the testing-staging Azure App Service.

### Azure

Azure resources are designed to be updated by the _infra_ Azure DevOps pipeline
after initially [creating Azure resources](bicep/README.md) for environments.

Note that Azure resources for rc-production is only updated from `prod` branch.

Even in `main` (testing-staging), the pipeline ought to be run manually only
when there are changes as the infrastructure deployment is not necessarily
idenpotent and could cause a brief interruption in customer-facing services.
Whether downtime is the case, depends on factors like App Service tier used.

### Azure DevOps

To reproduce the Azure DevOps project and the pipelines in your organisation,
see [creating Azure DevOps resources programmatically](devops/README.md).

For private projects, depending on the level of communication and size of the
team, it is highly recommended to configure deployment of feature branches
automatically to testing, just before the review (triggered by creating a PR),
even if testing is used as a shared environment between the team members.

For public projects, **never let PRs to be deployed to a shared environment**
without a review from a core team member - doing so might compromise security.
