#!/bin/sh

case ":$LD_LIBRARY_PATH:" in
  *":/opt/muos/extra/lib:"*) ;;
  *) export LD_LIBRARY_PATH="/opt/muos/extra/lib:$LD_LIBRARY_PATH" ;;
esac

. /opt/muos/script/var/func.sh
. /opt/muos/script/mux/close_game.sh

case "$(GET_VAR "device" "board/name")" in
	rg*) echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey" ;;
	*) ;;
esac

DEV_BOARD=$(GET_VAR "device" "board/name")
case "$DEV_BOARD" in
	rg40xx*)
		RGBCONF_SCRIPT="/run/muos/storage/theme/active/rgb/rgbconf.sh"
		if [ -f "$RGBCONF_SCRIPT" ]; then
			"$RGBCONF_SCRIPT"
		else
			/opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0
		fi
		;;
	*) ;;
esac

/opt/muos/device/current/input/combo/audio.sh I
/opt/muos/device/current/input/combo/bright.sh I

ACT_GO=/tmp/act_go
APP_GO=/tmp/app_go
ASS_GO=/tmp/ass_go
GOV_GO=/tmp/gov_go
ROM_GO=/tmp/rom_go

EX_CARD=/tmp/explore_card

MUX_RELOAD=/tmp/mux_reload
MUX_AUTH=/tmp/mux_auth

DEF_ACT=$(GET_VAR "global" "settings/general/startup")
printf '%s\n' "$DEF_ACT" >$ACT_GO
if [ "$DEF_ACT" = "explore" ]; then printf '%s\n' "explore_alt" >$ACT_GO; fi
EC=0

echo "root" >$EX_CARD

KILL_BGM() {
	if pgrep -f "playbgm.sh" >/dev/null; then
		killall -q "playbgm.sh" "mpg123"
	fi
}

if [ "$(GET_VAR "global" "settings/advanced/random_theme")" -eq 1 ]; then
	LOGGER "$0" "FRONTEND" "Changing to a random theme"
	/opt/muos/script/mux/theme.sh "?R"
fi

LAST_PLAY="/opt/muos/config/lastplay.txt"

LOGGER "$0" "FRONTEND" "Setting default CPU governor"
DEF_GOV=$(GET_VAR "device" "cpu/default")
printf '%s\n' "$DEF_GOV" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
if [ "$DEF_GOV" = ondemand ]; then
	GET_VAR "device" "cpu/sampling_rate_default" >"$(GET_VAR "device" "cpu/sampling_rate")"
	GET_VAR "device" "cpu/up_threshold_default" >"$(GET_VAR "device" "cpu/up_threshold")"
	GET_VAR "device" "cpu/sampling_down_factor_default" >"$(GET_VAR "device" "cpu/sampling_down_factor")"
	GET_VAR "device" "cpu/io_is_busy_default" >"$(GET_VAR "device" "cpu/io_is_busy")"
fi

LOGGER "$0" "FRONTEND" "Checking for last or resume startup"
if [ "$(GET_VAR "global" "settings/general/startup")" = "last" ] || [ "$(GET_VAR "global" "settings/general/startup")" = "resume" ]; then
	if [ -s "$LAST_PLAY" ]; then
		LOGGER "$0" "FRONTEND" "Checking for network and retrowait"
		if [ "$(GET_VAR "global" "network/enabled")" -eq 1 ] && [ "$(GET_VAR "global" "settings/advanced/retrowait")" -eq 1 ]; then
			NET_START="/tmp/net_start"
			OIP=0
			while true; do
				NW_MSG=$(printf "Waiting for network to connect... (%s)\n\nPress START to continue loading\nPress SELECT to go to main menu" "$OIP")
				/opt/muos/extra/muxstart "$NW_MSG"
				OIP=$((OIP + 1))
				if [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ]; then
					LOGGER "$0" "FRONTEND" "Network connected"
					/opt/muos/extra/muxstart "Network connected... Booting content!"
					break
				fi
				if [ "$(cat "$NET_START")" = "ignore" ]; then
					LOGGER "$0" "FRONTEND" "Ignoring network connection"
					/opt/muos/extra/muxstart "Ignoring network connection... Booting content!"
					break
				fi
				if [ "$(cat "$NET_START")" = "menu" ]; then
					LOGGER "$0" "FRONTEND" "Booting to main menu"
					/opt/muos/extra/muxstart "Booting to main menu!"
					break
				fi
				sleep 1
			done
		fi
		if [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ] || [ "$(cat "$NET_START")" = "ignore" ] || [ "$(GET_VAR "global" "network/enabled")" -eq 0 ] || [ "$(GET_VAR "global" "settings/advanced/retrowait")" -eq 0 ]; then
			LOGGER "$0" "FRONTEND" "Booting to last launched content"
			cat "$LAST_PLAY" >"$ROM_GO"
			/opt/muos/script/mux/launch.sh
		fi
	fi
	echo launcher >$ACT_GO
fi

/opt/muos/script/mux/golden.sh &

LOGGER "$0" "FRONTEND" "Starting frontend launcher"
cp /opt/muos/*.log "$(GET_VAR "device" "storage/rom/mount")/MUOS/log/boot/." &

while true; do
	# Background Music
	if [ "$(GET_VAR "global" "settings/general/bgm")" -eq 1 ]; then
		if ! pgrep -f "playbgm.sh" >/dev/null; then
			/opt/muos/script/mux/playbgm.sh &
		fi
	else
		KILL_BGM
	fi

	# Content Association
	if [ -s "$ASS_GO" ]; then
		ROM_NAME=$(sed -n '1p' "$ASS_GO")
		ROM_DIR=$(sed -n '2p' "$ASS_GO")
		ROM_SYS=$(sed -n '3p' "$ASS_GO")

		ROM_FORCED=$(sed -n '4p' "$ASS_GO")
		rm "$ASS_GO"

		if [ "$ROM_FORCED" -eq 1 ]; then
			printf "Content Association FORCED\n"
			echo "option" >$ACT_GO
		else
			echo "assign" >$ACT_GO
		fi
	fi

	# Content Governor
	if [ -s "$GOV_GO" ]; then
		ROM_NAME=$(sed -n '1p' "$GOV_GO")
		ROM_DIR=$(sed -n '2p' "$GOV_GO")
		ROM_SYS=$(sed -n '3p' "$GOV_GO")

		GOV_FORCED=$(sed -n '4p' "$GOV_GO")
		rm "$GOV_GO"

		if [ "$GOV_FORCED" -eq 1 ]; then
			printf "Content Governor FORCED\n"
			echo "option" >$ACT_GO
		else
			echo "governor" >$ACT_GO
		fi
	fi

	# Content Loader
	if [ -s "$ROM_GO" ]; then
		KILL_BGM
		/opt/muos/script/mux/launch.sh
	fi

	# Application Loader
	if [ -s "$APP_GO" ]; then
		KILL_BGM
		RUN_APP=$(cat $APP_GO)
		"$RUN_APP"
		rm "$APP_GO"
		continue
	fi

	# Get Last ROM Index
	if [ "$(cat $ACT_GO)" = explore ] || [ "$(cat $ACT_GO)" = favourite ] || [ "$(cat $ACT_GO)" = history ]; then
		if [ -s "/tmp/idx_go" ]; then
			LAST_INDEX_ROM=$(cat "/tmp/idx_go")
			rm "/tmp/idx_go"
		else
			LAST_INDEX_ROM=0
		fi
	fi

	# Kill PortMaster GPTOKEYB just in case!
	killall -q gptokeyb.armhf gptokeyb.aarch64 &

	# muX Programs
	if [ -s "$ACT_GO" ]; then
		case "$(cat $ACT_GO)" in
			"launcher")
				touch /tmp/pdi_go
				echo launcher >$ACT_GO
				if [ -s "$MUX_AUTH" ]; then
					rm "$MUX_AUTH"
				fi
				SET_VAR "system" "foreground_process" "muxlaunch"
				nice --20 /opt/muos/extra/muxlaunch
				;;
			"option")
				echo explore >$ACT_GO
				SET_VAR "system" "foreground_process" "muxoption"
				nice --20 /opt/muos/extra/muxoption
				;;
			"assign")
				echo option >$ACT_GO
				SET_VAR "system" "foreground_process" "muxassign"
				nice --20 /opt/muos/extra/muxassign -a 0 -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS"
				;;
			"governor")
				echo option >$ACT_GO
				SET_VAR "system" "foreground_process" "muxgov"
				nice --20 /opt/muos/extra/muxgov -a 0 -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS"
				;;
			"explore")
				echo launcher >$ACT_GO
				echo "$LAST_INDEX_SYS" >/tmp/lisys
				SET_VAR "system" "foreground_process" "muxassign"
				nice --20 /opt/muos/extra/muxassign -a 1 -c "$ROM_NAME" -d "$(cat /tmp/explore_dir)" -s none
				SET_VAR "system" "foreground_process" "muxgov"
				nice --20 /opt/muos/extra/muxgov -a 1 -c "$ROM_NAME" -d "$(cat /tmp/explore_dir)" -s none
				SET_VAR "system" "foreground_process" "muxplore"
				nice --20 /opt/muos/extra/muxplore -i "$LAST_INDEX_ROM" -m "$(cat $EX_CARD)"
				;;
			"explore_alt")
				if [ "$EC" -gt 0 ]; then echo launcher >"$ACT_GO"; fi
				SD1_COUNT=$(find "$(GET_VAR "device" "storage/rom/mount")"/ROMS -mindepth 1 -maxdepth 1 -type d | wc -l)
				SD2_COUNT=$(find "$(GET_VAR "device" "storage/sdcard/mount")"/ROMS -mindepth 1 -maxdepth 1 -type d | wc -l)
				USB_COUNT=$(find "$(GET_VAR "device" "storage/usb/mount")"/ROMS -mindepth 1 -maxdepth 1 -type d | wc -l)
				if { [ "$SD1_COUNT" -gt 1 ] && [ "$SD2_COUNT" -gt 1 ]; } ||
					{ [ "$SD1_COUNT" -gt 1 ] && [ "$USB_COUNT" -gt 1 ]; } ||
					{ [ "$SD2_COUNT" -gt 1 ] && [ "$USB_COUNT" -gt 1 ]; }; then
					echo "root" >"$EX_CARD"
				elif [ "$SD1_COUNT" -gt 1 ]; then
					echo "mmc" >"$EX_CARD"
					touch "/tmp/single_card"
				elif [ "$SD2_COUNT" -gt 1 ]; then
					echo "sdcard" >"$EX_CARD"
					touch "/tmp/single_card"
				elif [ "$USB_COUNT" -gt 1 ]; then
					echo "usb" >"$EX_CARD"
					touch "/tmp/single_card"
				else
					echo launcher >"$ACT_GO"
					continue
				fi
				SET_VAR "system" "foreground_process" "muxplore"
				nice --20 /opt/muos/extra/muxplore -i 0 -m "$(cat $EX_CARD)"
				EC=$((EC + 1))
				;;
			"app")
				echo launcher >$ACT_GO
				if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
					SET_VAR "system" "foreground_process" "muxpass"
					nice --20 /opt/muos/extra/muxpass -t launch
					if [ "$?" = 1 ]; then
						SET_VAR "system" "foreground_process" "muxapp"
						nice --20 /opt/muos/extra/muxapp
					fi
				else
					SET_VAR "system" "foreground_process" "muxapp"
					nice --20 /opt/muos/extra/muxapp
				fi
				;;
			"config")
				echo launcher >$ACT_GO
				if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
					if [ -e "$MUX_AUTH" ]; then
						SET_VAR "system" "foreground_process" "muxconfig"
						nice --20 /opt/muos/extra/muxconfig
					else
						SET_VAR "system" "foreground_process" "muxpass"
						nice --20 /opt/muos/extra/muxpass -t setting
						if [ "$?" = 1 ]; then
							SET_VAR "system" "foreground_process" "muxconfig"
							nice --20 /opt/muos/extra/muxconfig
							touch "$MUX_AUTH"
						fi
					fi
				else
					SET_VAR "system" "foreground_process" "muxconfig"
					nice --20 /opt/muos/extra/muxconfig
				fi
				;;
			"info")
				echo launcher >$ACT_GO
				SET_VAR "system" "foreground_process" "muxinfo"
				nice --20 /opt/muos/extra/muxinfo
				;;
			"tweakgen")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxtweakgen"
				nice --20 /opt/muos/extra/muxtweakgen
				;;
			"tweakadv")
				echo tweakgen >$ACT_GO
				SET_VAR "system" "foreground_process" "muxtweakadv"
				nice --20 /opt/muos/extra/muxtweakadv
				;;
			"theme")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxtheme"
				nice --20 /opt/muos/extra/muxtheme
				;;
			"visual")
				echo tweakgen >$ACT_GO
				SET_VAR "system" "foreground_process" "muxvisual"
				nice --20 /opt/muos/extra/muxvisual
				;;
			"storage")
				echo tweakadv >$ACT_GO
				SET_VAR "system" "foreground_process" "muxstorage"
				nice --20 /opt/muos/extra/muxstorage
				;;
			"net_profile")
				echo network >$ACT_GO
				SET_VAR "system" "foreground_process" "muxnetprofile"
				nice --20 /opt/muos/extra/muxnetprofile
				;;
			"net_scan")
				echo network >$ACT_GO
				SET_VAR "system" "foreground_process" "muxnetscan"
				nice --20 /opt/muos/extra/muxnetscan
				;;
			"network")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxnetwork"
				nice --20 /opt/muos/extra/muxnetwork
				;;
			"webserv")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxwebserv"
				nice --20 /opt/muos/extra/muxwebserv
				;;
			"rtc")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxrtc"
				nice --20 /opt/muos/extra/muxrtc
				;;
			"language")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxlanguage"
				nice --20 /opt/muos/extra/muxlanguage
				;;
			"timezone")
				echo rtc >$ACT_GO
				SET_VAR "system" "foreground_process" "muxtimezone"
				nice --20 /opt/muos/extra/muxtimezone
				;;
			"tester")
				echo info >$ACT_GO
				SET_VAR "system" "foreground_process" "muxtester"
				nice --20 /opt/muos/extra/muxtester
				;;
			"device")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxdevice"
				nice --20 /opt/muos/extra/muxdevice
				;;
			"system")
				echo info >$ACT_GO
				SET_VAR "system" "foreground_process" "muxsysinfo"
				nice --20 /opt/muos/extra/muxsysinfo
				;;
			"favourite")
				find "/run/muos/storage/info/favourite" -maxdepth 1 -type f -size 0 -delete
				echo launcher >$ACT_GO
				SET_VAR "system" "foreground_process" "muxplore"
				nice --20 /opt/muos/extra/muxplore -i "$LAST_INDEX_ROM" -m favourite
				if [ -s "$MUX_RELOAD" ]; then
					if [ "$(cat $MUX_RELOAD)" -eq 1 ]; then
						echo favourite >$ACT_GO
					fi
					rm "$MUX_RELOAD"
				fi
				;;
			"history")
				find "/run/muos/storage/info/history" -maxdepth 1 -type f -size 0 -delete
				echo launcher >$ACT_GO
				SET_VAR "system" "foreground_process" "muxplore"
				nice --20 /opt/muos/extra/muxplore -i 0 -m history
				if [ -s "$MUX_RELOAD" ]; then
					if [ "$(cat $MUX_RELOAD)" -eq 1 ]; then
						echo history >$ACT_GO
					fi
					rm "$MUX_RELOAD"
				fi
				;;
			"credits")
				echo info >$ACT_GO
				SET_VAR "system" "foreground_process" "muxcredits"
				nice --20 /opt/muos/extra/muxcredits
				;;
			"reboot")
				HALT_SYSTEM frontend reboot
				;;
			"shutdown")
				HALT_SYSTEM frontend poweroff
				;;
		esac
	fi
done
