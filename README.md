[![GitHub](https://img.shields.io/github/license/beeminder/BeeSwift)](https://github.com/beeminder/BeeSwift/)
[![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/beeminder/BeeSwift?sort=semver)](https://github.com/beeminder/BeeSwift/tags)
[![Semaphore CI test status](https://andrewpbrett.semaphoreci.com/badges/BeeSwift.svg)](https://andrewpbrett.semaphoreci.com)

# BeeSwift
Official Beeminder for iOS app

## Features
 - native iOS app
 - [Apple Health integration](#apple-health-integration)
 - today widget, displaying up to three goals and allowing quick data entry
 - gallery view of all of a user's active goals
 - facilitates viewing one's goals and their status
 - provides notifications of pending goal deadlines
 - provides a means to easily add data manually for a goal
 - login via any of the following combinations: email/password, username/password
 - less bright white while in Dark Mode

## Apple Health integration

Using Apple Health as a source, data can be syncronized from the Apple Health app to a Beeminder goal. The following metrics are supported:
 - Steps
 - Active energy
 - Exercise time
 - Weight
 - Cycling distance
 - Walking/running distance
 - Nike Fuel
 - Water
 - Time in bed
 - Time asleep
 - Resting energy
 - Dietary energy
 - Dietary protein
 - Dietary sugar
 - Dietary carbs
 - Dietary fat
 - Dietary saturated fat
 - Dietary sodium
 - Swimming strokes
 - Swimming distance
 - Mindful minutes
 - ~Stand hours~ _(currently disabled/unavailable)_

## Download Beeminder for iOS

[![Download on the App Store](https://linkmaker.itunes.apple.com/en-us/badge-lrg.svg?releaseDate=2012-08-30&kind=iossoftware&bubble=ios_apps)](https://apps.apple.com/us/app/beeminder/id551869729?mt=8)

## Development

### Installation/Setup
The file `BeeSwift/Config.swift` is ignored by git since it has sensitive info like keys in it. Copy `BeeSwift/Config.sample.swift` to `BeeSwift/Config.swift` and uncomment the struct it contains so that the project can reference the struct.

There's a Run Script build phase that references `BeeSwift/Sentry.sh`, which is also ignored by git since it has an auth token. Either create an empty shell script at that location (preferable) or delete the `Run Script - Sentry` build phase (if you do delete it, make sure not to check in the modified `project.pbxproj` file).

The project should build at this point and run in the simulator.

If it's still not building, or if you find other noteworthy dependencies not listed here, please create a new issue! Or a pull request with a modified Readme.

### Testing

Since the Beeminder backend/web application isn't open source (yet), you'll need to ask us to be added to the private repo if you want to be able to point the iOS app at `localhost:3000`. You can also create a test account/goal on beeminder.com to test against.

### Contributing

Read and sign [beeminder.com/cla](http://beeminder.com/cla). Then make a branch off of master and send a pull request!
