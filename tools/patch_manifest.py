#!/usr/bin/env python3
"""Menyesuaikan AndroidManifest.xml hasil `flutter create` untuk XyCloudStore.

Yang ditambahkan:
  - nama aplikasi  : XyCloudStore
  - izin internet
  - activity penangkap balikan login sosial (skema xycloudstore://)
  - daftar <queries> supaya bisa membuka WhatsApp, browser, dan email

Pemakaian: python3 tools/patch_manifest.py android/app/src/main/AndroidManifest.xml
"""
import re
import sys

ACTIVITY_CALLBACK = """
        <activity
            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
            android:exported="true">
            <intent-filter android:label="flutter_web_auth_2">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="xycloudstore"/>
            </intent-filter>
        </activity>
    </application>"""

QUERIES = """    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="mailto"/>
        </intent>
        <intent>
            <action android:name="android.support.customtabs.action.CustomTabsService"/>
        </intent>
        <package android:name="com.whatsapp"/>
        <package android:name="com.whatsapp.w4b"/>
    </queries>
</manifest>"""


def main() -> int:
    berkas = sys.argv[1] if len(sys.argv) > 1 else 'android/app/src/main/AndroidManifest.xml'
    isi = open(berkas, encoding='utf-8').read()

    isi = re.sub(r'android:label="[^"]*"', 'android:label="XyCloudStore"', isi, count=1)

    if 'android.permission.INTERNET' not in isi:
        isi = isi.replace(
            '<application',
            '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
            1,
        )

    if 'flutter_web_auth_2.CallbackActivity' not in isi:
        isi = isi.replace('    </application>', ACTIVITY_CALLBACK, 1)

    if '<queries>' not in isi:
        isi = isi.replace('</manifest>', QUERIES, 1)

    open(berkas, 'w', encoding='utf-8').write(isi)
    print('AndroidManifest.xml diperbarui:', berkas)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
