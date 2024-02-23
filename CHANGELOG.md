# Changelog

Changes to be released in next version
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️  API Changes
 * 

🧱 Build
 * 

Others
 * 

6.6 (Release date TBD)
=================================================

✨ Features
 * New Apple Heath Metrics: Time in Daylight (#421)

🙌 Improvements
 * For some Apple Health Metrics, show only a reasonable number of digits (#438)
 * Show the bee lemniscate when goals are queued for server-side processing (#444)
 * Ignore derailment and pessimistic datapoints when suggesting datapoint value (#441)

🐛 Bugfix
 * Disconnecting goals from Apple Health allows deadline to be set (#437)
 * Apple Health data is now correctly set for the current day for non-midnight deadlines (#433)
 * The edit datapoints view now dismisses after editing or deleting a goal (#445)
 * Refreshing goals should not trigger an autodata update for manual goals (#446)
 * No longer reset changes to datapoint value on switching between apps (#442)

⚠️  API Changes
 * Write requestIds for HealthKit data points (#419)
 * Use HTTP Header to authenticate against the beeminder API (#447)
 * First experimental introduction of Core Data to store user information (#423)

🧱 Build
 * Only run each test once as part of CI (#415)
 * Updating a PR now cancels previous runs (#432)
 * File hierarchy is changed so most files are now only compiled once (#425)

Others
 * Minimum iOS version is now iOS15 (#416)


6.5 (2023-10-04)
=================================================

✨ Features
 * Sync Workout Minutes with Apple Health (#401)

🙌 Improvements
 * Pull to refresh autodata is now more obvious and works with Apple Health (#410)
 * Redesigned Edit Datapoint view (#413)

🐛 Bugfix
 * Fix occasional crash on initializing HealthKit connection (#414)


6.4 (2023-08-08)
=================================================

🙌 Improvements
 * Move the beeminder access token to secure storage in the iOS Keychain (#394)

🐛 Bugfix
 * App no longer crashes when modifying notification settings (#400)
 * Some users with bad data experienced a crash on app load (#399)
 * Today widget should not crash if goals are not available (#398)
 * Refreshing a goal once again causes autodata to update
 * Bring back the timer control


6.3 (2023-07-17)
=================================================

BeeSwift now only supports iOS 14.0+

✨ Features
 * Application logs can now be viewed and shared (e.g. to send to support) (#384)
 * Confirmation screen with data preview when linking goals to HealthKit (#364)
 * Add support for a number of additional HealthKit metrics

🙌 Improvements
 * Speed up and rate limit background health data updates (#372, #373, #374)
 * HealthKit metrics are now shown grouped by category (#343)
 * Correctly render values for hhmm goals in the list of recent data points (#337)
 * Improve styling of additional keyboard buttons

🐛 Bugfix
 * Goals in the gallery are sorted according to the canonical beeminder sort (#382)
 * Correctly calculate sleep time (#359)
 * Correctly calculate time in bed, meditation minutes, and stand hours
 * Do not sync health data from before a goal was created (#358)
 * Do not prompt to upgrade immediately to allow most users to auto-update (#341)

🧱 Build
 * Migrate from CocoaPods to SwiftPM (#380)
 * Upgrade several third party dependencies (#342)
 * Update rubygem versions (#375, #385)

⚖️  Compliance
 * Remove all features which link from the app to the beeminder website (#388, #390, #391)
 * Remove mention of pledge amounts (#389)


6.2 (2022-10-14)
=================================================

🙌 Improvements
 * Reduce how often we re-fetch datapoints in response to Healthkit metric updates (#318)

🧱 Build
 * Remove broken tests (#319)
 * Tests are now run through github action s(#316)


6.1 (2022-10-04)
=================================================

✨ Features
 * Gallery view shows ticks next to goals which have data for the day (#299)

🙌 Improvements
 * Shortcuts can now specify a comment when adding data points (#310)

🐛 Bugfix
 * Fixed HealthKit not performing background sync after upgrade (#313, #314)
 * Fixed Shortcuts integration failing for most users (#303)
 * Fix Icon rendering glitch when entering settings dialog multiple times (#307)

⚠️ API Changes
 * Removes dependencies on some unused API attributes to allow server clean up. (8800d2b)


## 5.9. (2021-01-28)
=================================================

✨ Features
 * 

🙌 Improvements
 * Removed the "Unlock your phone to sync your Health data with Beeminder" notifications, which were often delivered nonsensically. [#44](https://github.com/beeminder/BeeSwift/issues/44)

🐛 Bugfix
 * 

⚠️ API Changes
 *

🧱 Build
 * 

Others
 * 


## 5.8. (2020-10-20)
=================================================

✨ Features
 * 

🙌 Improvements
 * Clarify instructions for Apple Health goals [#170](https://github.com/beeminder/BeeSwift/issues/170)
 * Add pull to refresh on the goal screen [#84](https://github.com/beeminder/BeeSwift/issues/84)
 * Add a link for resetting a forgotten password [#173](https://github.com/beeminder/BeeSwift/issues/173)
 * Show divider on sign in / sign up
 * Update the datapoint comment for Apple Health goals to match other autodata goals [#195](https://github.com/beeminder/BeeSwift/issues/195)
 * improve handling of 'no more free accounts currently available' when signing up

🐛 Bugfix
 * Fix the bug of missing icons on older versions of iOS [#158](https://github.com/beeminder/BeeSwift/issues/158)
 * Fix a bug where a duplicate datapoint would be displayed on the goal screen [#166](https://github.com/beeminder/BeeSwift/issues/166) 
 * Fix a crasher when updating Apple Health goals in the background [#179](https://github.com/beeminder/BeeSwift/issues/179)
 * Fix the app badge not being updated after the user signs out [#40](https://github.com/beeminder/BeeSwift/issues/40)
 * Remove the tiny black border around the icon that appeared in version 5.7 [#178](https://github.com/beeminder/BeeSwift/issues/178)

⚠️ API Changes
 *

🧱 Build
 * Update Semaphore configuration with new sentry slug
 * bump AlamofireImage from 3.5.2 to 3.6.0
 * bump Alamofire from 4.8.2 to 4.9.1
 * Bump Sentry from 4.5.0 to 5.2.0

Others
 * Update license to reflect MIT for code and something else for Beeminder branding


## 5.7. (Aug 20, 2020)

 * Added some padding around the bee in the app icon [#25](https://github.com/beeminder/BeeSwift/issues/25) [#139](https://github.com/beeminder/BeeSwift/pull/139)
 * Elaborate on contributing guidelines [#138](https://github.com/beeminder/BeeSwift/pull/138)
 * Use SafariViewController when viewing existing goals externally (webbrowser) [#128](https://github.com/beeminder/BeeSwift/pull/128)
 * Specify Background Fetch minimum [#129](https://github.com/beeminder/BeeSwift/pull/129)
 * Updates to the process of linking a goal to Apple Health: better sorting of goals to indicate which ones can be linked, instructions on the screen, and the checkmark no longer disappears [#85](https://github.com/beeminder/BeeSwift/issues/25), [#122](https://github.com/beeminder/BeeSwift/pull/122)
 * Keep selected health metric when saving [#116](https://github.com/beeminder/BeeSwift/issues/116), [#121](https://github.com/beeminder/BeeSwift/pull/121)
 * Tweak Signin/Signup Screen [#110](https://github.com/beeminder/BeeSwift/pull/110)
 * Use SafariViewController when creating a new goal (webbrowser) [#119](https://github.com/beeminder/BeeSwift/pull/119)
 * Remove 3rd party logins [#67](https://github.com/beeminder/BeeSwift/issues/67), [#73](https://github.com/beeminder/BeeSwift/issues/73), [#107](https://github.com/beeminder/BeeSwift/pull/107)
 * Fix sorting by recent data [#100](https://github.com/beeminder/BeeSwift/issues/100), [#101](https://github.com/beeminder/BeeSwift/pull/101)
 * Do not remind user to unlock device when Beeminder is visible [#44](https://github.com/beeminder/BeeSwift/issues/44), [#78](https://github.com/beeminder/BeeSwift/pull/78)
 * Reuse relevant graphs in gallery (avoid constant flickering) [#43](https://github.com/beeminder/BeeSwift/issues/43), [#103](https://github.com/beeminder/BeeSwift/pull/103)
 * Fix scrolling in Goal screen of Health sourced goals [#99](https://github.com/beeminder/BeeSwift/pull/99)
 * Additional images and tweaks to make dark mode look a little better [#95](https://github.com/beeminder/BeeSwift/pull/95)
 * Use graph placeholder in Today Widget [#104](https://github.com/beeminder/BeeSwift/pull/104)
 * Use httpS (no longer plaintext http) when communicating with services [#91](https://github.com/beeminder/BeeSwift/issues/91), [#105](https://github.com/beeminder/BeeSwift/pull/105)
 * You can now see more than one goal in the Today widget [#92](https://github.com/beeminder/BeeSwift/issues/92), [#93](https://github.com/beeminder/BeeSwift/pull/93)
 * Show graph placeholder sooner in Goal screen [#82](https://github.com/beeminder/BeeSwift/pull/82)
 * Provide launchscreen as Storyboard [#66](https://github.com/beeminder/BeeSwift/issues/66), [#83](https://github.com/beeminder/BeeSwift/pull/83)
 * There's now a cancel button in search bar to make it easier to go back to showing all goals [#53](https://github.com/beeminder/BeeSwift/issues/53), [#65](https://github.com/beeminder/BeeSwift/pull/65)

## 5.6.4 (June 9, 2020)
 - Bug fix (for real this time): the intermittent blank white screen is, we believe, vanquished for good.
 - Bug fix: for entering datapoints > 1000 (i.e., with a comma in US-style notation), the app no longer switches said comma to a decimal point
 - Bug fix: if you delete a datapoint, the datapoint now immediately disappears from the list of datapoints under the graph
 - Bug fix: similarly, if you edit a datapoint, the datapoint under the graph is now immediately updated. Furthermore, the value in the data entry field changes to reflect the edit.
 - Improvement: if a background fetch fails, there is no longer an alert ("Error fetching goals") waiting for you when you return to the app.
 - Improvement: we now prompt you to turn on notifications when switching to a new device or on a reinstall of the app, if necessary.

## 5.6.3 (May 6, 2020)
 - Bug fix: for the intermittent blank screen on loading
 - Bug fix: for the goal screen not updating the "Safe for X days" text if you added data elsewhere and then tapped the refresh button.

## 5.6.2 (Apr 23, 2020)
 - Time zone now displayed in Settings
 - The information about the minimum requirements each day is now under the graph.
 - Bug fix: when you entered invalid credentials, you previously were bombarded with multiple popups telling you that they were invalid, over and over. Now you just get one, which seems sufficient.
 - Bug fix, introduced briefly in 5.6: the sort feature was broken, now it's fixed.
 - Bug fix, introduced briefly in 5.6.1: the most recent datapoint was not showing underneath the graph
 - Search bar results are now preserved after you view an individual goal and return to the gallery screen

## 5.6.1 (Apr 22, 2020)
 - Bug fix, introduced briefly in 5.6: the sort feature was broken, now it's fixed.

## 5.6 (Apr 18, 2020)
 - You can now filter goals by their name (slug) by tapping the search icon in the upper left
 - More concise information about what you need to do, by when, to meet your goal
 - Additional health metrics: Saturated fat and sodium
 - Time zone now displayed in Settings
 - The information about the minimum requirements each day is now under the graph.
 - Bug fix: when you entered invalid credentials, you previously were bombarded with multiple popups telling you that they were invalid, over and over. Now you just get one, which seems sufficient.

## 5.5 (Nov 5, 2019)
 - Some small bug fixes, including the mystery of intermittently disappearing goals on the gallery screen.

## 5.4.1 (Aug 7, 2019)
 - Adds dietary sugar, carbs, and fat to the Apple Health integration
 - Fix for adding data from the Today widget
 - Updates to syncing spinners to make it more apparent that syncing has happened
 - Fix to display the Beeminder-correct date if the goal's deadline has already passed for the day
 - Other sundry bug fixes

## 5.4 (Apr 11, 2019)
 - No more hanging spinner of doom.
 - The app should be more likely to be up to date as soon as you switch back to it.
 - Health data should be able to consolidate the data when it’s coming from multiple sources (like the watch + the phone + different apps) rather than adding it all together.
 - Health data should sync automatically in the background.

## 5.3 (Sep 14, 2018)
 - New Apple Health metrics: Dietary energy, resting energy, and dietary protein
 - Bug fix for the refresh spinner getting stuck
 - Match the ordering for datapoints under the graph with the website

## 5.2 (Aug 10, 2018)
 - Edit and delete datapoints! Just tap the one you want below the graph
 - Bug fix: duplicate datapoints for health goals should now no longer be duplicated
 - The datapoints below the graph should now always match the website's version of the truth

## 5.1 (Jun 11, 2018)
 - Updates to the HealthKit integration, including fixes for Mindful Minutes and the addition of Stand Hours

## 5.0.1 (Jan 17, 2018)
 - A notice on the gallery screen - currently you have to create new goals on the Beeminder website. This will soon be available in the app!

## 5.0 (Jan 3, 2018)
 - Timer mode: from a goal screen, tap the timer icon to bring up a timer screen and easily submit datapoints for timed activities.

## 4.9 (Dec 28, 2017)
 - Goals can now be sorted by name, deadline, pledge, and recently updated, just like on the web dashboard
 - The Settings screen got a (mostly cosmetic) overhaul
 - Lots of refactoring and updates under the hood
 - **The app is also now open source! https://github.com/beeminder/BeeSwift**

## 4.8.1 (Nov 28, 2017)
 - Small bug fix for some people with Apple Health goals that was crashing the app for people. Sorry about that!

## 4.8 (Nov 14, 2017)
 - Bug fixes for goals linked to Apple Health:
   - Mindful minutes goals should no longer overwrite data
   - all goals should no longer record duplicate data points

## 4.7 (Jul 13, 2017)
 - Bugfix for Apple Health weight goals not updating with new data.
 - Bugfix for multiple metrics appearing to be selected when pairing
 - Bugfix for goals paired to Apple Health not updating after reinstalling the app

## 4.6 (Jun 28, 2017)
 - Bugfix! For the mystery of the duplicate datapoints.
 - New metrics for Apple Health goals! Now tracking mindful minutes, sleep, time in bed, and water consumption.
 - Bugfix! No longer crashing on older models of the iPad.

## 4.5.3 (Jun 9, 2017)
 - fixes a crash on iPhones 5 and older, once and for all, that was occurring when trying to display the bare minimum amounts for some goals.

## 4.5.2 (May 22, 2017)
 - fixes a crash that was occurring when trying to display the bare minimum amounts for some goals.

## 4.5.1 (May 12, 2017)
 - fixes a crash that was occurring with the Today screen if you had less than three Beeminder goals.

## 4.5 (May 11, 2017)
 - Updated Today widget: you can now add (integer) data directly from the Today screen.
 - Apple Health integration: you can now automatically sync data like steps, active energy, and workout distances from Apple Health to a Beeminder goal.
 - The goal screen now includes a button to view the goal on mobile Safari.

## 4.4 (Dec 14, 2016)
 - You can now create a Beeminder account from the app
 - Reset Data button to reload all goals
 - No longer show backburner dividing line
 - Bug fixes for push notifications
 - You can now tap "Create goal" which will log you in to the mobile website to create a new goal

## 4.3 (Apr 30, 2016)
 - fixes for easier login:
   - the app no longer crashes when you try to log in with Facebook
   - the app no longer just hangs when you try to log in with Google
 - Two other smaller fixes
   - if you were seeing the app crash when adding a datapoint, that's fixed now (it happened when the request timed out or otherwise came back with an error)
   - And if you have fewer goals than what fills the gallery screen, you can now pull to refresh (but really - you should probably just have more Beeminder goals!).

## 4.2 (Nov 23, 2015)
 - Graphs now appear in the Today widget along with the minimum required to stay on the road
 - Notifications and reminders revamp: you can adjust the individual goal and default notification settings from the settings screen
 - Reload button on goal screen triggers refresh of autodata sources
 - Fix for the dreaded spinner bug
 - Add a ":" button to allow for data input in HH:MM format
 - If a goal's deadline is after midnight, and it's after midnight the suggested day for data input is the previous day
 - Bug fix for Arabic numerals
