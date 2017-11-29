# BeeSwift
Official Beeminder for iOS app

### Installation/Setup
The file `BeeSwift/Config.swift` is ignored by git since it has sensitive info like keys in it. Copy `BeeSwift/Config.sample.swift` to `BeeSwift/Config.swift` and uncomment the struct it contains so that the project can reference the struct.

There's a Run Script build phase that references `BeeSwift/Sentry.sh`, which is also ignored by git since it has an auth token. Either create an empty shell script at that location (preferable) or delete the `Run Script - Sentry` build phase (if you do delete it, make sure not to check in the modified `project.pbxproj` file).

The project should build at this point. If not, check on the following two items:

If it complains about `GoogleService-Info.plist`, try copying `GoogleService-Info.sample.plist` to that location. You can also get a sample plist file from [Google's documentation](https://developers.google.com/identity/sign-in/ios/start-integrating).

Code signing/provisioning profiles settings.

If it's still not building, please create a new issue!
