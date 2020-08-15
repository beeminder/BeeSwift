## Contributing

#### Legal Schmegal

First, please read and sign [beeminder.com/cla](https://beeminder.com/cla).

#### Set up

See [Getting Started](GETTING_STARTED.md) for instructions on how to get the app running locally on XCode.

#### Development flow

We follow the [GitHub flow](https://guides.github.com/introduction/flow/) conventions for development.

We recommend [forking](https://guides.github.com/activities/forking/) to your own repository as the first step. Add your repository as a remote named `origin` and add this repository (beeminder/BeeSwift) as a remote named `upstream`.

To start work on a new feature/bug fix, make a branch off of master.

```
git checkout -b branch-name-here --no-track upstream/master
```

Before submitting a pull request, rebase your work off the current master branch.

We have a (currently very limited) suite of tests set up on [Semaphore CI](https://andrewpbrett.semaphoreci.com/projects/BeeSwift). Pull requests that add to the test suite are very welcome and encouraged! Submitting a pull request from your fork will trigger a build on Semaphore. If the pull request looks good and everything is green on Semaphore, the PR will be merged after a review.

#### Deployment

We have [Fastlane](https://fastlane.tools) set up to manage uploading builds to TestFlight and the App Store and tagging commits as appropriate. 
