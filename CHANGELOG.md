# Changelog

## 5.7. (Aug 20, 2020)

 - There's now a cancel button in search bar to make it easier to go back to showing all goals
 - Images on the gallery screen no longer flicker
 - You can now see more than one goal in the Today widget
 - Additional images and tweaks to make dark mode look a little better
 - Updates to the process of linking a goal to Apple Health: better sorting of goals to indicate which ones can be linked, instructions on the screen, and the checkmark no longer disappears
 - Added some padding around the bee in the app icon
 - Bugfix: the app badge now goes away if you log out of Beeminder

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

