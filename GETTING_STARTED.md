## Getting Started

This is a guide to getting the Beeminder app running in your Xcode Simulator/test device.

#### Installation/Setup

Copy BeeKit/Config.sample.swift to BeeKit/Config.swift, or create the file BeeKit/Config.swift that at least contains:

    public struct Config {
          public let baseURLString = "https://www.beeminder.com"
    }

The project should build at this point and run in the simulator.

If it's still not building, or if you find other noteworthy dependencies not listed here, please create a new issue! Or a pull request with a modified version of this file.

#### Testing

Since the Beeminder backend/web application isn't open source (yet), you'll need to ask us to be added to the private repo if you want to be able to point the iOS app at localhost:3000. You can also create a test account/goal on beeminder.com to test against.

#### Code Formatting

The codebase is formatted using swift-format. A check on CI will fail when the code of a meege request does not comply.

##### lane

A lane in fastlane can be used to format the code.


##### pre-commit
The [pre-commit tool](https://pre-commit.com) can be used to configure git with the pre-commit hook provided in the repository.

Install the tool:
```
brew install precommit
pre-commit --install
```

It will now run at the start of a git commit. 
It can also be run manually:

`pre-commit run --all-files`


#### Contributing

See [Contributing](CONTRIBUTING.md) for more. 
