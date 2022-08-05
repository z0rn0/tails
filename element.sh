#!/bin/bash
set -e

echo "============================="
echo "add persistent folders"
echo "============================="
custom_mounts=$(realpath /tmp/custom_mounts-*.list)
persistence_file=/live/persistence/TailsData_unlocked/persistence.conf

ensure_in_persistence () {
    target=$1
    
    folder_name=$2
    persistence_line="$target source=$folder_name"
    if ! grep -qxF "$persistence_line" "$persistence_file"; then 
        # add to persistence.conf
        echo "$persistence_line" \
            >> $persistence_file

        # add to custom_mounts-xxxx.list
        echo "/dev/mapper/TailsData_unlocked /live/persistence/TailsData_unlocked/$folder_name $target source=$folder_name" \
            >> $custom_mounts
        
        echo "$folder_name got added"
    fi
}
ensure_in_persistence /home/amnesia/.local/share/applications applications
ensure_in_persistence /home/amnesia/.local/share/flatpak flatpak
ensure_in_persistence /home/amnesia/.var/app var_app
ensure_in_persistence /var/cache/apt/archives apt/cache
ensure_in_persistence /var/lib/apt/lists apt/lists

# This will import activate_custom_mounts()
. /lib/live/boot/9990-misc-helpers.sh

# ignore warnings from activate_custom_mounts()
log_warning_msg () { 
    :
}

# Have activate_custom_mounts create new directories with safe permissions (#7443)
OLD_UMASK="$(umask)"
umask 0077 

# mount newly added persistent folders 
activate_custom_mounts "${custom_mounts}" &> /dev/null

umask "$OLD_UMASK" # restore


echo ""
echo "============================="
echo "install dependencies"
echo "============================="
# already add packages to the auto-install list to avoid a user prompt
additional_software_file=/live/persistence/TailsData_unlocked/live-additional-software.conf
if [ -z $(grep flatpak "$additional_software_file") ]; then 
    echo flatpak >> $additional_software_file
fi
if [ -z $(grep xdg-desktop-portal-gtk "$additional_software_file") ]; then 
    echo xdg-desktop-portal-gtk >> $additional_software_file
fi

apt-get update
apt-get install -y flatpak xdg-desktop-portal-gtk

sudo -u amnesia torify flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo


echo ""
echo "============================="
echo "install element"
echo "============================="

sudo -u amnesia torify flatpak install -y flathub im.riot.Riot

# create application entry
cat <<EOF > /home/amnesia/.local/share/applications/Element.desktop
[Desktop Entry]
Type=Application
Name=Element
Icon=/home/amnesia/.local/share/flatpak/app/im.riot.Riot/current/active/files/share/icons/hicolor/128x128/apps/im.riot.Riot.png
Exec=env /usr/bin/flatpak run --branch=stable --arch=x86_64 --command=/app/bin/element --file-forwarding im.riot.Riot --proxy-server=socks5://127.0.0.1:9050 @@u %U @@
Categories=Network;InstantMessaging;Chat;VideoConference;
MimeType=x-scheme-handler/element;
StartupWMClass=element
Keywords=Matrix;matrix.org;chat;irc;communications;talk;riot;vector;
EOF
chown amnesia:amnesia /home/amnesia/.local/share/applications/Element.desktop

echo ""
echo "Element successfully installed!"
echo "It should now appear in your application menu"
