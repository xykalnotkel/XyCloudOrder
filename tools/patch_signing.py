#!/usr/bin/env python3
"""Menyisipkan konfigurasi penandatanganan rilis ke berkas Gradle Android.

Dipakai oleh GitHub Actions setelah `flutter create --platforms=android`.
Mendukung Groovy (build.gradle) maupun Kotlin DSL (build.gradle.kts).
"""
import os
import re
import sys

APP_DIR = sys.argv[1] if len(sys.argv) > 1 else "android/app"

groovy = os.path.join(APP_DIR, "build.gradle")
kts = os.path.join(APP_DIR, "build.gradle.kts")

if os.path.exists(groovy):
    path, mode = groovy, "groovy"
elif os.path.exists(kts):
    path, mode = kts, "kts"
else:
    sys.exit("build.gradle tidak ditemukan di " + APP_DIR)

src = open(path, encoding="utf-8").read()

if "signingConfigs.release" in src:
    print("Sudah dipatch, dilewati.")
    sys.exit(0)

if mode == "groovy":
    header = """
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
"""
    signing = """
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }
"""
else:
    header = """
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
"""
    signing = """
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
"""

# 1) sisipkan pemuat key.properties sebelum blok android { }
m = re.search(r"^android\s*\{", src, re.M)
if not m:
    sys.exit("Blok android { } tidak ditemukan.")
src = src[: m.start()] + header.strip() + "\n\n" + src[m.start():]

# 2) sisipkan signingConfigs tepat setelah pembuka blok android { }
m = re.search(r"^android\s*\{", src, re.M)
src = src[: m.end()] + "\n" + signing.rstrip() + "\n" + src[m.end():]

# 3) arahkan buildTypes.release ke signingConfig rilis
subs = [
    (r"signingConfig\s*=?\s*signingConfigs\.debug", "signingConfig = signingConfigs.release"
        if mode == "groovy" else 'signingConfig = signingConfigs.getByName("release")'),
    (r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
        'signingConfig = signingConfigs.getByName("release")'),
]
diganti = False
for pat, rep in subs:
    src, n = re.subn(pat, rep, src)
    if n:
        diganti = True

if not diganti:
    # tidak ada baris debug: tambahkan blok release ke buildTypes
    rep = ("signingConfig = signingConfigs.release" if mode == "groovy"
           else 'signingConfig = signingConfigs.getByName("release")')
    m = re.search(r"buildTypes\s*\{", src)
    if not m:
        sys.exit("buildTypes tidak ditemukan.")
    blok = ("\n        release {\n            %s\n        }\n" % rep if mode == "groovy"
            else '\n        getByName("release") {\n            %s\n        }\n' % rep)
    src = src[: m.end()] + blok + src[m.end():]

open(path, "w", encoding="utf-8").write(src)
print("Berhasil patch signing pada", path, "(" + mode + ")")
