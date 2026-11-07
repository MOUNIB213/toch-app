# Tech News (أخبار التقنية)
1. `flutter create --org com.technews --project-name tech_news .`  (داخل هذا المجلد، لا تستبدل lib/ و pubspec.yaml)
2. `flutter pub get && dart run flutter_launcher_icons`
3. android/app/src/main/AndroidManifest.xml قبل <application>:
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
4. android/app/build.gradle: داخل compileOptions أضف `coreLibraryDesugaringEnabled true`
   وفي dependencies: `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'` (مطلوب للإشعارات)
5. عدّل بريدك/تيليجرام في lib/ui.dart (devEmail, devTelegram) ثم `flutter run`
