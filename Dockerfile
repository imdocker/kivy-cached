FROM ubuntu

ENV SDK_TOOLS="sdk-tools-linux-4333796.zip"
ENV NDK_DL="https://dl.google.com/android/repository/android-ndk-r17c-linux-x86_64.zip"
ENV NDKVER=r17c
ENV NDKDIR=/ndk/
ENV NDKAPI=21
ENV ANDROIDAPI=28
ENV PIP=pip3

# Basic image upgrade:
RUN apt update --fix-missing && apt upgrade -y

# Install base packages
RUN apt update && apt install -y zip python3 python-pip python python3-venv python3-virtualenv python-virtualenv python3-pip curl wget lbzip2 bsdtar && dpkg --add-architecture i386 && apt update && apt install -y build-essential libstdc++6:i386 zlib1g-dev zlib1g:i386 openjdk-8-jdk libncurses5:i386 && apt install -y libtool automake autoconf unzip pkg-config git ant gradle rsync

# Install Android SDK:
RUN mkdir /sdk-install/
RUN cd /sdk-install && wget --quiet https://dl.google.com/android/repository/${SDK_TOOLS} \
&&  cd /sdk-install && unzip -q ./sdk-tools-*.zip && chmod +x ./tools//bin/sdkmanager \
&&  rm -v sdk-tools-*.zip
RUN /sdk-install/tools/bin/sdkmanager --update
RUN yes | /sdk-install/tools/bin/sdkmanager "platform-tools" "platforms;android-28" "build-tools;28.0.3"

# Obtain Android NDK:
RUN mkdir -p /tmp/ndk/ && cd /tmp/ndk/ && wget --quiet ${NDK_DL} && unzip -q android-ndk*.zip && mv android-*/ /ndk/ && rm -v android-ndk*.zip

# Install shared packages:
# Enable ccache:
RUN apt install -y ccache
ENV USE_CCACHE 1
ENV CCACHE_DIR /ccache/contents/
ENV CC ccache gcc
ENV CCACHE_DEBUG 1
ENV CCACHE_LOGFILE /ccache/contents/cache.debug.txt
VOLUME /ccache/

# Fix SDK permissions:
RUN if [ -x /sdk-install ]; then chmod a+x /sdk-install/tools/bin/*; fi

# Force-update pip to latest version:
RUN ${PIP} install -U pip

# Dependencies for extra python modules:
RUN apt update && apt install -y libffi-dev libssl-dev

# Make sure Cython is up-to-date:
RUN $PIP install -U Cython

# Install additional tools useful for all environments:
RUN apt update && apt install -y cmake

# Tools for debugging:
RUN apt update && apt install -y nano vim tree

# SDL2 development headers:
RUN apt update && apt install -y libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev

# Prepare user environment:
RUN apt install -y psmisc bash sudo
RUN /bin/echo -e '\nBASH_ENV="~/.additional_env"\n' >> /etc/environment
ENV BASH_ENV="~/.additional_env"
RUN mkdir -p /home/userhome/
ENV HOME /home/userhome
ENV BUILDUSERNAME root

# Workspace folder (if used, otherwise the following line will be blank):
VOLUME /home/userhome/workspace/

# Volume for output:
VOLUME /home/userhome/output

# Set start directory:
WORKDIR /home/userhome

# Drop privileges:


# Install shared user packages:
# Install p4a & buildozer as regular user:
RUN $PIP install --user -U 'buildozer' 'https://github.com/kivy/python-for-android/archive/master.zip' #  # p4a build 63768e71-3198-48f7-aa59-bf38dabb2e68

# Get the kivy test app:
RUN mkdir -p /tmp/test-app/ && cd /tmp/test-app && git clone https://github.com/kivy/python-for-android/ .
RUN cp -R /tmp/test-app/testapps/testapp_keyboard/ /home/userhome/testapp-sdl2-keyboard/
RUN cp -R /tmp/test-app/testapps/testapp_flask/ /home/userhome/testapp-webview-flask/
RUN cp -R /tmp/test-app/testapps/testapp_nogui/ /home/userhome/testapp-service_only-nogui/

# Final command line preparation:
RUN echo 'bash' > /tmp/launchcmd.txt
RUN /bin/echo -e '#!/usr/bin/python3\n\
import json\n\
import os\n\
print("echo \"\"")\n\
print("echo \"  *** WELCOME to p4a-build-spaces ***\"\\n")\n\
print("echo \"\"\\n")\n\
print("echo \"To build a kivy demo app, use this command:\"")\n\
print("echo \"\"\\n")\n\
init_file = ""\n\
if os.environ["PIP"] == "pip2":\n\
    demoapp_line = "echo \"$ cd ~/testapp-sdl2-keyboard && p4a apk --arch=armeabi-v7a --name test --package com.example.test --version 1 --requirements=kivy,python2 --private .\"\\n"\n\
    print(demoapp_line)\n\
    init_file += "shopt -s expand_aliases\\n"\n\
    init_file += "alias testbuild=\"cd ~/testapp-sdl2-keyboard && p4a apk --arch=armeabi-v7a --name test --package com.example.test --version 1 --requirements=kivy,python2 --private . && cp *.apk ~/output\"\\n"\n\
    init_file += "alias testbuild_webview=\"cd ~/testapp-webview-flask && p4a apk --arch=armeabi-v7a --name test --package com.example.test --version 1 --bootstrap webview --requirements=python2,flask --private . && cp *.apk ~/output\"\\n"\n\
    init_file += "alias testbuild_service_only=\"cd ~/testapp-service_only-nogui && p4a apk --arch=armeabi-v7a --name test --package com.example.test --version 1 --bootstrap service_only --requirements=pyjnius,python2 --private . && cp *.apk ~/output\"\\n"\n\
else:\n\
    demoapp_line = "echo \"$ cd ~/testapp-sdl2-keyboard && p4a apk --arch=armeabi-v7a --name test --package com.example.test --version 1 --requirements=kivy,python3 --private .\"\\n"\n\
    print(demoapp_line)\n\
    init_file += "shopt -s expand_aliases\\n"\n\
    init_file += "alias testbuild=\"cd ~/testapp-sdl2-keyboard && p4a apk --arch=armeabi-v7a --name test --package com.example.test --version 1 --requirements=kivy,python3 --private . && cp *.apk ~/output\"\\n"\n\
    init_file += "alias testbuild_webview=\"cd ~/testapp-webview-flask && p4a apk --arch=armeabi-v7a --name test --package com.example.test --version 1 --bootstrap webview --requirements=python3,flask --private . && cp *.apk ~/output\"\\n"\n\
    init_file += "alias testbuild_service_only=\"cd ~/testapp-service_only-nogui && p4a apk --arch=armeabi-v7a --name test --package com.example.test --version 1 --bootstrap service_only --requirements=pyjnius,python3 --private . && cp *.apk ~/output\"\\n"\n\
print("echo \"\"\\n")\n\
print("echo \"... or use the shortcut alias \\`testbuild\\`!\"\\n")\n\
print("echo \"\"\\n")\n\
with open("/tmp/launchcmd.txt", "r") as f:\n\
    import shlex\n\
    args = shlex.split(f.read().strip())\n\
    print("CMD=()")\n\
    i = -1\n\
    for arg in args:\n\
        i += 1\n\
        print("CMD[" + str(i) + "]=" + shlex.quote(arg))\n\
vars = ["ANDROIDAP='$ANDROIDAPI'",\n\
    "ANDROIDNDKVER='$NDKVER'",\n\
    "NDKAPI='$NDKAPI'",\n\
    "HOME=/home/userhome",\n\
    "GRADLE_OPTS=\"-Xms1724m -Xmx5048m -Dorg.gradle.jvmargs='"'"'-Xms1724m -Xmx5048m'"'"'\"",\n\
    "JAVA_OPTS=\"-Xms1724m -Xmx5048m\"",\n\
    "TESTPATH=\"$PATH:/home/userhome/.local/bin\"",\n\
    "PATH=\"$PATH:/home/userhome/.local/bin\"",\n\
    "ANDROIDSDK=/sdk-install/ ANDROIDNDK=\"'$NDKDIR'\"",\n\
    ]\n\
with open(os.path.expanduser("~/.pam_environment"), "a", encoding="utf-8") as f1:\n\
    f1.write("\\n" + "\\n".join([\n\
        var.partition("=")[0] + " DEFAULT=" +\n\
        var.partition("=")[2] for var in vars]))\n\
with open(os.path.expanduser("~/.bash_profile"), "a", encoding="utf-8") as f2:\n\
    f2.write("\\n" + init_file + "\\n")\n\
    f2.write("\\n" + "\\nexport ".join(vars) + "\\n")\n\
with open(os.path.expanduser("~/.profile"), "a", encoding="utf-8") as f2:\n\
    f2.write("\\n" + "\\nexport ".join(vars) + "\\n")\n\
with open(os.path.expanduser("~/.bashrc"), "a", encoding="utf-8") as f2:\n\
    f2.write("\\n" + init_file + "\\n")\n\
    f2.write("\\n" + "\\nexport ".join(vars) + "\\n")\n\
with open(os.path.expanduser("~/.additional_env"), "a", encoding="utf-8") as f3:\n\
    f3.write("\\n" + "\\nexport ".join(vars) + "\\n")' > /tmp/cmdline.py

# Actual launch script:
RUN /bin/echo -e '#!/bin/sh\n\
python3 /tmp/cmdline.py > /tmp/launch-prepare.sh\n\
source /tmp/launch-prepare.sh\n\
exec -- ${CMD[@]}' > /tmp/launch.sh
