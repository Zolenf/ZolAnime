# zolanime
A application for watching anime add free with sync on different devices

## About

ZolAnime is an app that allows you easily watch your favourite anime without having to deal with ads. Also the biggest feature is automatic synchronization between devices so you can stop your watching session on pc and hop on phone right away with episode starting in exact time you finished last time. (app autosaves progress 0.3 sec after stopping video so for it to work properly try to wait a little after stopping and then leave)
For scraping episodes app uses [AnivexaApi](https://github.com/walterwhite-69/Anivexa-API) and [MiruroApi](https://github.com/walterwhite-69/Miruro-API) with slight changes made by walterwhite-69

## setup
You need an [Anilist](https://anilist.co) account to use it inside the app.
Download the newest version from [Releases](../../releases/latest) or compile it yourself.
When you log in, Zolanime will sync your watching progress with Anilist database

## Tips

App is still more or less buggy so there are some tips:
  * **if video is not loading after more than 15 seconds** try switching to another server. if it does not work then click terminal icon in top right corner, copy the most recent logs and open an Issue on this repo
  * **if something goes wrong and application missread/misssave courrent episode** try manually editing watching progress on anilist website or their android app
  * **in time of writing this there is no way to add anime to planning section** other than manually on anilist site or in their app, but you can use integrated browser to search up anime and add it to watching section
  * **if you can't find anime in integrated browser** then try adding it to watching list on anilist website or their app 

## Compiling
just clone the repo, install flutterSDK and hit:
  `flutter pub get`
  `flutter run`
