#!/system/bin/sh
export LC_ALL=C
S0=${EPOCHREALTIME//./}
CHUNK=${CHUNK:-16}
PARALLEL=${PARALLEL:-0}

R=$(cat <<'EOF'
run(){ a=$1; k=$2; shift 2
  t1=${EPOCHREALTIME//./}; r=$("$@" 2>&1); rc=$?; t2=${EPOCHREALTIME//./}
  st=P; [ "$rc" -eq 0 ] || st=F
  echo "$t2|$g|$t_in|$k|$a|$t1|$t2|$rc|$MY_PID|${r//$'\n'/ }|$((t2-t1))|$st"; }
skip(){ a=$1; k=$2
  t=${EPOCHREALTIME//./}
  echo "$t|$g|$t_in|$k|$a|$t|$t|-|$MY_PID|excluded|0|S"; }
noupd(){ a=$1; k=$2
  t=${EPOCHREALTIME//./}
  echo "$t|$g|$t_in|$k|$a|$t|$t|-|$MY_PID|no-update|0|N"; }
is_in(){ case " $1 " in *" $2 "*) return 0;; *) return 1;; esac; }
EOF
)
eval "$R"

W=$(cat <<'EOF'
ph=$1; shift; MY_PID=$$
for l; do
  g=${l%%=*}; p=${l#*=}; t_in=${EPOCHREALTIME//./}
  case $ph in
    dex)    run delete-dexopt "$p" cmd package delete-dexopt "$p" ;;
    stopA)  is_in "$EXCL_STOP" "$p" && { skip stop-app "$p"; continue; }
            run stop-app "$p" cmd activity stop-app "$p" ;;
    stopB)  is_in "$EXCL_STOP" "$p" && { skip force-stop "$p"; continue; }
            run force-stop "$p" cmd activity force-stop "$p" ;;
    sysupd) is_in "$NOUPD_CLR" "$p" && { noupd uninstall-sysupd "$p"; continue; }
            is_in "$SYSUPD_EXCL" "$p" && { skip uninstall-sysupd "$p"; continue; }
            run uninstall-sysupd "$p" cmd package uninstall-system-updates "$p" ;;
    clr)    is_in "$CLEAR_EXCL" "$p" && { skip pm-clear "$p"; continue; }
            run pm-clear "$p" cmd package clear "$p" ;;
    global) is_in "$GLOBAL_SKIP" "$p" && { skip settings-glb "$p"; continue; }
            run settings-glb "$p" cmd settings delete global "$p" ;;
    secure) is_in "$SECURE_SKIP" "$p" && { skip settings-sec "$p"; continue; }
            run settings-sec "$p" cmd settings delete secure "$p" ;;
    system) is_in "$SYSTEM_SKIP" "$p" && { skip settings-sys "$p"; continue; }
            run settings-sys "$p" cmd settings delete system "$p" ;;
  esac
done
EOF
)

sysrun(){ a=$1; shift; g=0; MY_PID=$$; t_in=${EPOCHREALTIME//./}; run "$a" SYSTEM "$@"; }
fan(){ xargs -n "$CHUNK" -P "$PARALLEL" sh -c "$R
$W" _ "$1"; }

EXTRACT_PKGS(){ grep -oE '[A-Za-z0-9_.]+/' | tr -d /; }
_q(){ cmd package query-activities --brief -a "$1" 2>/dev/null | EXTRACT_PKGS | sort -u; }
SYS_ONLY(){ awk 'BEGIN{n=split(ENVIRON["SYS_LIST"],a,"\n");for(i=1;i<=n;i++)if(a[i]!="")sys[a[i]]=1} NF&&($0 in sys)'; }
EXT_QA(){ awk '{
    for(i=1;i<=NF;i++) if($i ~ /^packageName=/){ s=$i; sub(/^packageName=/,"",s); print s }
    if ($0 ~ /^[a-z][a-z0-9_.]*$/) print $0
  }' | awk 'NF' | sort -u; }
DEDUP(){ tr ' ' '\n' | awk 'NF' | sort -u | tr '\n' ' '; }

# ============================================================
# STATIC
# ============================================================

# pm clear: 15 статических пакетов (провайдеры, launcher, encrypted, settings)
CLEAR_STATIC="\
com.samsung.android.server.wifi.mobilewips com.samsung.android.smartface \
com.ss.launcher2 com.android.providers.settings com.android.providers.downloads \
com.android.nfc com.android.mtp com.android.stk com.android.stk2 \
com.android.externalstorage com.android.providers.userdictionary \
com.samsung.android.mdx com.sec.android.app.desktoplauncher com.sec.android.app.dexonpc \
com.samsung.android.smartmirroring"

# uninstall-system-updates: 15 статических пакетов (критичные обновляемые)
SYSUPD_STATIC="\
com.google.android.providers.media.module com.google.android.gms com.android.vending \
com.google.android.googlequicksearchbox com.google.android.youtube com.android.chrome \
com.google.android.webview com.android.providers.telephony com.google.android.cellbroadcastreceiver \
com.sec.android.app.samsungapps com.google.android.gsf \
com.google.android.syncadapters.calendar com.google.android.partnersetup \
com.google.android.configupdater com.google.android.cellbroadcastservice"

SYSTEM_SKIP="\
SMLDM_BEARER SOUNDALIVE_AUDIO_PATH accelerometer_rotation access_control_enabled adaptive_fast_charging \
add_info_com_samsung_android_app_routines#dashboard add_info_com_samsung_android_forest#screenTime add_info_com_sec_android_daemonapp#weather \
alarm_alert alarm_alert_CONSTANT_PATH alarm_alert_set alertoncall_mode android.contacts.DISPLAY_ORDER android.contacts.SORT_ORDER \
aod_charging_mode aod_content_type aod_edgeclock_pos aod_mode aod_mode_end_time aod_mode_start_time aod_notifications aod_tap_to_show_mode \
attfota_forceinstall_FN_sim auto_brightness_transition_time autoredial_mode badge_for_dm_battery bixby_setting_show_app_icon_enabled \
call_conn_tone call_end_tone call_extra_volume call_noise_reduction charger_connected_time charging_info_always cmf_color_code \
cocktail_bar_enabled_cocktails colortheme_app_icon contactsaveto country_cert_info_enable csc_pref_camcorder_resolution_key \
csc_pref_camera_flash_key csc_pref_camera_forced_shuttersound_key csc_pref_setup_storage_key current_tty_mode current_tty_mode_2 \
custom_wallpaper_color_areas_lock delete_shared_screenshots dexonpc_connection_state display_night_theme display_night_theme_scheduled \
dls_state dualclock_menu_settings edge_handler_position_percent edge_lighting edge_lighting_basic_color_index \
edge_lighting_show_condition edge_lighting_version epdg_support2 eth_disabled exclude_systemui_screenshots \
face_widget_detail_setting face_widget_order face_widget_res_id fmm_notification_other game_no_interruption \
game_no_interruption_white_list headphone_monitoring hide_rotation_lock_toggle_for_accessibility high_brightness_mode_pms_enter \
k2hd_effect last_status_logging lockstar_enabled ltw_connected ltw_smartview_connected mcf_continuity min_minder \
mode_ringer_streams_affected motion_pick_up multi_control_enabled night_mode_end_time night_mode_start_time \
notification_sound notification_sound_2 notification_sound_2_CONSTANT_PATH notification_sound_2_set \
notification_sound_CONSTANT_PATH notification_sound_set phone1_on phone2_on pms_notification_panel_brightness_adjustment \
preload_fingerprint preload_install_history qs_detail_content_primary_text_color qs_detail_content_secondary_text_color \
radio.data.stall.recovery.action0 radio.data.stall.recovery.action1 rcs_user_setting2 restore_panel_list \
ringtone ringtone_2 ringtone_2_CONSTANT_PATH ringtone_2_set ringtone_CONSTANT_PATH ringtone_set \
samsung_eula_agree scheduled_to_apply_special_theme screen_brightness screen_brightness_mode sec_anomaly_config \
servicebox_page_gravity settings_reset_ctb_support show_password shown_max_brightness_dialog \
sip_speak_keyboard_input_aloud smart_capture_screenshot_format time_12_24 user_rotation vibrate_when_ringing \
videocall_type2 videocall_type voicecall_type2 voicecall_type volume_assistant_bt_a2dp volume_music_bt_a2dp \
volume_music_earpiece volume_music_speaker volume_notification_bt_a2dp volume_notification_earpiece \
volume_notification_speaker volume_ring_earpiece volume_ring_speaker volume_system_bt_a2dp volume_system_earpiece \
volume_system_speaker volumekey_mode vowifi_menu_enable vset_enabled wallpaper_finish_drawing wbamr_mode \
wfc_call_menu2 wfc_quicksetting_menu2 wfc_setting_menu2 white_lockscreen_navigationbar white_lockscreen_statusbar \
white_lockscreen_wallpaper wifi_call_enable2 wifi_call_preferred2 wireless_fast_charging"

GLOBAL_SKIP="\
Phenotype_boot_count adb_allowed_connection_time adb_enabled adb_wifi_enabled appwidget_prevent_remove_all \
audio_safe_volume_state auto_time auto_time_zone autofill_compat_mode_allowed_packages \
backup_agent_timeout_parameters bluetooth_btsnoop_default_mode bluetooth_last_device_version bluetooth_on \
bluetooth_sanitized_exposure_notification_supported boot_count carrier_app_names carrier_app_whitelist \
cert_pin_content_url cert_pin_metadata_url check_private_ip_mode cmc_activation cmc_device_type \
cmc_is_emergency_call_supported cmc_menu_supported cmc_network_type cmc_oobe cmc_own_settings_menu_supported \
cmc_same_wifi_network_status cmc_service_version colortheme_app_icon content_capture_service_explicitly_enabled \
data_roaming debug_app development_settings_enabled device_oneui_version device_provisioned edge_enable \
edge_handle_size_percent edge_handle_transparency edge_panel_height edge_panel_width \
function_key_config_doublepress_value galaxy_system_update_block headphone_monitoring is_default_bg_sim1 \
is_default_bg_sim2 lighting_color_backup_version limit_brightness_state location_popup_sim_off_count \
mobile_data mode_capability mode_display_name mode_enabled mode_id mode_ringer_time_on multi_cb \
multi_sim_data_call multi_sim_data_call_slot multi_sim_datacross_slot multi_sim_dds_progressing \
multi_sim_existing_data_call multi_sim_existing_sms multi_sim_existing_voice_call multi_sim_sms \
multi_sim_sms_slot multi_sim_voice_call multi_sim_voice_call_slot multisound_state \
navigation_bar_gesture_disabled_by_policy navigationbar_color navigationbar_current_color network_avoid_bad_wifi \
network_recommendations_enabled network_scoring_ui_enabled network_watchlist_last_report_time \
notification_sort_order online_manual_url package_verifier_user_consent private_dns_mode private_dns_specifier \
protect_battery psm_5G_mode quickstar_qs_tile_layout_custom_matrix ram_expand_size ram_expand_size_list \
register_allow_data_dialog_retry_to_alarm_manager reset_fplmn_function_mode_set \
sem_enhanced_cpu_responsiveness sem_power_mode_refresh_rate sem_power_mode_refresh_rate_cover \
sem_wifi_switch_to_better_wifi_enabled sem_wifi_switch_to_better_wifi_supported send_action_app_error \
set_network_mode_by_quick_panel sim_slot_switching_state sip_migrate_status smart_view_show_notification_on \
sms_short_codes_content_url sms_short_codes_metadata_url spam_call_mute_first_ring swipe_directly_to_quick_setting \
swipe_directly_to_quick_setting_area swipe_directly_to_quick_setting_position sysui_demo_allowed \
sysui_tuner_demo_on updatable_driver_production_allowlist updatable_driver_production_denylist \
use_video_sound_for_ringtone use_video_sound_for_ringtone_sim2 user_disabled_hdr_formats verifier_timeout \
wait_for_debugger wifi_display_on wifi_iwc_last_time_switch_to_mobile_on wifi_networks_available_notification_on \
wifi_on wifi_scan_always_enabled wifi_switch_for_individual_apps_detection_mode \
wifi_watchdog_poor_network_test_enabled wifi_wcm_qos_sharing_score_summary zen_mode zen_mode_config_etag"

SECURE_SKIP="\
accessibility_button_mode accessibility_enabled accessibility_magnification_activated \
accessibility_magnification_capability accessibility_shortcut_target_service active_unlock_provider \
active_unlock_target android_id assistant autofill_field_classification autofill_service_search_uri \
autofill_user_data_max_category_count backup_manager_constants biometrics_strong_enroll_timestamp \
bluetooth_a2dp_bt_uhq_state bluetooth_a2dp_uhqa_support bluetooth_address bluetooth_cast_mode bluetooth_name \
bluetooth_settings_foreground bonded_device_clientside bonded_device_d2dMHSside bonded_device_mhsside \
brightness_on_top bt_a2dp_audio_latency client_advanced_autohotspot_run clock_seconds \
com.google.android.gms.tapandpay.tokenization.CACHED_BACKUP_STATUS config_update_certificate \
default_input_method default_voice_input_method device_state_rotation_lock dropbox:data_app_anr \
dropbox:data_app_crash dropbox:data_app_wtf dymlock_suspend_multiwallpaper_switching edge_lighting_recommend_app_list \
emergency_gesture_enabled enabled_accessibility_services enabled_input_methods enabled_notification_listeners \
enhanced_comfort_font_value face_brighten_screen face_stay_on_lock_screen face_unlock_attention_required \
facelock_detection_threshold facelock_liveliness_recognition_threshold facelock_max_center_movement \
fingerprint_screen_off_icon_aod fixed_delete_mode_rule fixed_delete_reminder flashlight_available \
flashlight_enabled fmm_access_url fmm_main_switch_support fmm_offline_find_support fmm_tag_enhanced_tracking \
game_auto_temperature_control game_autobrightness_lock game_bixby_block game_double_swipe_enable \
game_edgescreen_touch_lock game_show_floating_icon game_touchscreen_lock gamesdk_version high_priority \
icon_blacklist incall_power_button_behavior input_methods_subtype_history key_plugin_lock_instance_data \
keyguard_slice_uri lockscreen.options lockscreen_imei_setting lockstar_facewidget_area \
mandatory_biometrics_requirements_satisfied masterLocationPackagePrefixBlacklist \
masterLocationPackagePrefixWhitelist mate_setting_activation multi_sim_bar_show_on_qspanel nas_settings_updated \
navigation_mode nearby_sharing_component nfc_payment_default_component nfc_payment_foreground \
notification_history_enabled offline_device_lock_setting pai_selection_page_complete plugin_lock_wallpaper_type \
pref_allowed_number_sgg pref_allowed_number_wallpaper_settings pref_dynamic_plugin_connected \
pref_dynamic_plugin_version preferred_rtt_mode print_service_search_uri pubkey_blacklist qs_button_grid \
qspanel_media_quickcontrol_bar_available qspanel_media_quickcontrol_bar_available_on_top refresh_rate_mode \
reminder_migration_finished remote_lock_setting sec_silent_auto_reset secure_vset_enabled \
selected_input_method_subtype selected_spell_checker selected_spell_checker_subtype \
sem_sp_edition_flipfont_changed send_action_app_error serial_blacklist settings_secure_routine_enabled \
sip_keyboard_type_mouse_id_list smart_tethering_db_migration smart_tethering_db_ver \
snoozed_schedule_condition_provider spatial_audio_enabled ssl_session_cache sysui_do_not_disturb \
sysui_keyguard_left sysui_keyguard_right sysui_qqs_count sysui_qs_tiles sysui_removed_qs_tiles \
sysui_rounded_size sysui_tuner_version sysui_volume_down_silent sysui_volume_up_silent \
theft_detection_lock_setting theft_detection_lock_supported theft_protection_default_on \
trust_agents_initialized tts_default_locale user_setup_complete voice_interaction_service \
voice_recognition_service wifi_ap_Tss_handled wifi_ap_chip_maxclient wifi_ap_chip_support5g \
wifi_ap_chip_support5g_baseon_country wifi_ap_customer wifi_ap_powersave_mode_checked wifi_ap_smart_d2d_mhs \
wifi_ap_wifi_sharing wifi_client_smart_tethering_settings wifi_mwips zen_settings_updated"

export SYSTEM_SKIP GLOBAL_SKIP SECURE_SKIP

# ============================================================
# INIT: stop/force-stop (3 запроса → focus + media.module)
# ============================================================
init_excl_stop(){
  f=$(dumpsys window displays 2>/dev/null); f=${f#*mFocusedApp=}; f=${f#* u* }
  focus=${f%%/*}
  media=$(printf '%s\n%s\n' \
    "$(_q android.provider.action.PICK_IMAGES_SETTINGS)" \
    "$(_q android.os.storage.action.CLEAR_APP_CACHE)" | sort | uniq -d | head -n1)
  printf 'com.google.android.providers.media.module %s %s' "$focus" "$media"
}

# ============================================================
# INIT: pm clear (34 MIN-PURE запроса, ≤5 extras каждый)
# ============================================================
init_excl_target(){
  D=$(
    {
      cmd package query-receivers  -a androidx.work.diagnostics.REQUEST_DIAGNOSTICS &
      cmd package query-receivers  -a com.samsung.intent.action.EMERGENCY_STATE_CHANGED &
      cmd package query-receivers  -a com.google.android.c2dm.intent.RECEIVE &
      cmd package query-receivers  -a androidx.profileinstaller.action.SKIP_FILE &
      cmd package query-activities -a com.samsung.android.spv.ACTION_VIEW_DETAIL &
      cmd package query-receivers  -a android.app.action.ENTER_KNOX_DESKTOP_MODE &
      cmd package query-receivers  -a android.intent.action.PRE_BOOT_COMPLETED &
      cmd package query-activities -a android.appwidget.action.APPWIDGET_CONFIGURE &
      cmd package query-receivers  -a android.intent.action.SIM_STATE_CHANGED &
      cmd package query-receivers  -a com.google.android.gms.phenotype.UPDATE &
      cmd package query-receivers  -a com.sec.android.app.setupwizard.SETUPWIZARD_COMPLETE &
      cmd package query-services   -a android.telephony.NetworkService &
      cmd package query-receivers  -a com.samsung.android.scpm.policy.CLEAR_DATA &
      cmd package query-activities -a .KeyBindingsActivity &
      cmd package query-activities -a CALLPLUS_SHOW_TOOLTIP_ACTION &
      cmd package query-services   -a android.accessibilityservice.AccessibilityService &
      cmd package query-receivers  -a android.app.action.STATSD_STARTED &
      cmd package query-receivers  -a android.autoinstalls.config.action.PLAY_AUTO_INSTALL &
      cmd package query-receivers  -a android.bluetooth.a2dp-sink.profile.action.CONNECTION_STATE_CHANGED &
      cmd package query-activities -a android.content.pm.action.CONFIRM_INSTALL &
      cmd package query-activities -a android.credentials.INSTALL &
      cmd package query-receivers  -a android.intent.action.BADGE_COUNT_UPDATE &
      cmd package query-receivers  -a android.intent.action.DEVICE_STORAGE_LOW &
      cmd package query-activities -a android.intent.action.REVIEW_PERMISSION_USAGE &
      cmd package query-receivers  -a android.intent.action.USER_REMOVED &
      cmd package query-receivers  -a android.media.STREAM_DEVICES_CHANGED_ACTION &
      cmd package query-receivers  -a android.net.wifi.p2p.CONNECTION_STATE_CHANGE &
      cmd package query-services   -a android.telecom.InCallService &
      cmd package query-activities -a com.android.setupwizard.OEM_POST_SETUP &
      cmd package query-receivers  -a androidx.profileinstaller.action.SAVE_PROFILE &
      cmd package query-receivers  -a com.samsung.android.intent.action.REQUEST_BACKUP_GALLERY_EVENT &
      cmd package query-services   -a com.samsung.android.provider.filterprovider.INSERT_MYFILTER &
      cmd package query-services   -a com.samsung.mcfserver.SMCF &
      cmd package query-services   -a com.samsung.systemui.action.PLUGIN_LOCK &
      wait
    } 2>/dev/null | EXT_QA | SYS_ONLY | DEDUP
  )
  printf '%s' "$D"
}

init_excl_clear(){
  TGT=$(init_excl_target)
  printf '%s %s' "$CLEAR_STATIC" "$TGT" | DEDUP
}

# ============================================================
# INIT: uninstall-system-updates (8 запросов, sum ≤25)
# ============================================================
init_excl_sysupd(){
  D=$(
    {
      # 8 запросов: 1 жирный (c2dm.RECEIVE 25 extras) + 7 нулевых
      cmd package query-receivers  -a com.google.android.c2dm.intent.RECEIVE &
      cmd package query-activities -a .settings.EngineSettings &
      cmd package query-receivers  -a android.autoinstalls.config.action.PLAY_AUTO_INSTALL &
      cmd package query-receivers  -a android.intent.action.USER_PRESENT &
      cmd package query-services   -a android.sec.speech.RecognitionSystemService &
      cmd package query-services   -a android.service.credentials.CredentialProviderService &
      cmd package query-activities -a android.settings.WEBVIEW_LICENSE &
      cmd package query-activities -a android.app.supervision.action.VIEW_APP_FILTER_SETTINGS &
      wait
    } 2>/dev/null | EXT_QA | SYS_ONLY | DEDUP
  )
  printf '%s %s' "$SYSUPD_STATIC" "$D" | DEDUP
}

# ============================================================
# MAIN INIT
# ============================================================
echo "INIT: raw..." >&2
RAW=$(cmd package list packages -s -f 2>/dev/null)
SYS_LIST=$(printf '%s\n' "$RAW" | awk '{ sub(/^package:/,""); sub(/.*=/,""); if($0!="") print }' | sort -u)
NOUPD_CLR=$(printf '%s\n' "$RAW" | awk '{ sub(/^package:/,""); eq=index($0,"="); if(eq==0)next; dir=substr($0,1,eq-1); pkg=substr($0,eq+1); if(dir !~ /\/data\/app\//) print pkg }' | tr '\n' ' ')
export SYS_LIST NOUPD_CLR

echo "INIT: exclusions..." >&2
EXCL_STOP=$(init_excl_stop)
CLEAR_EXCL=$(init_excl_clear)
SYSUPD_EXCL=$(init_excl_sysupd)
export EXCL_STOP CLEAR_EXCL SYSUPD_EXCL

[ -z "$CLEAR_EXCL" ]  && { echo "FATAL: CLEAR_EXCL empty" >&2;  exit 1; }
[ -z "$SYSUPD_EXCL" ] && { echo "FATAL: SYSUPD_EXCL empty" >&2; exit 1; }

echo "INIT: EXCL_STOP=$(printf '%s' "$EXCL_STOP" | wc -w) CLEAR=$(printf '%s' "$CLEAR_EXCL" | wc -w) SYSUPD=$(printf '%s' "$SYSUPD_EXCL" | wc -w) NOUPD=$(printf '%s' "$NOUPD_CLR" | wc -w)" >&2

PL_ALL=$(cmd package list packages | awk 'NF { sub(/^package:/,""); if($0!="") print ++n"="$0 }')
PL_SYS=$(printf '%s\n' "$RAW" | awk 'NF { sub(/^package:/,""); sub(/.*=/,""); if($0!="") print ++n"="$0 }')

# ============================================================
# EXEC + REPORT
# ============================================================
{
  sysrun pm-trim-caches cmd package trim-caches 999g
  printf '%s\n' "$PL_ALL" | fan dex
  printf '%s\n' "$PL_ALL" | fan stopA
  printf '%s\n' "$PL_ALL" | fan stopB
  printf '%s\n' "$PL_SYS" | fan sysupd
  printf '%s\n' "$PL_SYS" | fan clr
  sysrun am-kill-all cmd activity kill-all
  cmd settings list global | awk 'NF { sub(/=.*/,""); if($0!="") print ++n"="$0 }' | fan global
  cmd settings list secure | awk 'NF { sub(/=.*/,""); if($0!="") print ++n"="$0 }' | fan secure
  cmd settings list system | awk 'NF { sub(/=.*/,""); if($0!="") print ++n"="$0 }' | fan system
} | awk -F'|' -v S="$S0" '
function qsort(a,l,r,  i,j,p,t){ if(l>=r)return; i=l;j=r;p=a[int((l+r)/2)]
  while(i<=j){ while(a[i]<p)i++; while(a[j]>p)j--; if(i<=j){t=a[i];a[i]=a[j];a[j]=t;i++;j--} }
  qsort(a,l,j); qsort(a,i,r) }
function pctl(a,n,p,  i){ if(n<1)return 0; i=int(n*p/100+0.5); if(i<1)i=1; if(i>n)i=n; return a[i] }
BEGIN{ last_time=S }
{
  cmd_count++; if($7>last_time) last_time=$7
  is_sys=($4=="SYSTEM")
  if(!is_sys){ if(!($9 in wseq)){wseq[$9]=++wnum; wpid[wnum]=$9} w=wseq[$9]; wp=++wpc[$9] } else { w=0; wp="S" }
  tin_us=$3-S; tout_us=$1-S; t1_us=$6-S; dur_us=$11+0; status=$12
  if(!is_sys){ worker_busy[w]+=dur_us
    if(!(w in w_t_first)||tin_us<w_t_first[w]) w_t_first[w]=tin_us
    if(tout_us>w_t_last[w]) w_t_last[w]=tout_us }
  if(!($5 in seen_act)){ seen_act[$5]=1; act_names[++act_names_n]=$5 }
  msg=($10==""?"none":$10)
  if(status=="P") P++
  else if(status=="F"){ F++; nfail++; fail_pkg[nfail]=$4; fail_act[nfail]=$5; fail_code[nfail]=$8; fail_msg[nfail]=msg }
  else if(status=="S") SKIP++
  else NOUPD++
  act=$5; act_count[act]++; act_st[act,status]++
  if(status=="P"||status=="F"){
    act_sum_us[act]+=dur_us
    if(!(act in act_min)||dur_us<act_min[act]) act_min[act]=dur_us
    if(dur_us>act_max[act]) act_max[act]=dur_us
    act_durs[act,++act_n[act]]=dur_us
    d=int(dur_us/1000); total_dur+=d; total_us+=dur_us
    if(d>max_dur) max_dur=d
    if(d>0&&(min_dur==0||d<min_dur)) min_dur=d
  }
  printf "№%d|g:%s|w:%d|wp:%s|pid:%s|in:%.1fms|out:%.1fms|t1-s0:%.1fms|dur:%.1fms|act:%s|pkg:%s|resp:%s|code:%s|st:%s|P:%d/F:%d/S:%d/N:%d\n", cmd_count,$2,w,wp,$9,tin_us/1000,tout_us/1000,t1_us/1000,dur_us/1000,$5,$4,msg,$8,status,P,F,SKIP,NOUPD
}
END{
  total_time=int((last_time-S)/1000); attempted=P+F
  avg_dur=attempted?total_dur/attempted:0; success_rate=attempted?P*100/attempted:0
  throughput=total_time?cmd_count*1000/total_time:0
  exec_ms=total_us/1000; wall_ms=total_time; par_factor=wall_ms>0?exec_ms/wall_ms:0
  min_first=1e18
  for(i=1;i<=wnum;i++){
    if(worker_busy[i]>max_busy) max_busy=worker_busy[i]
    if(w_t_first[i]<min_first) min_first=w_t_first[i]
    if(w_t_first[i]>max_first) max_first=w_t_first[i]
    wall_w=w_t_last[i]-w_t_first[i]
    if(wall_w>0){ sum_occ+=worker_busy[i]*100/wall_w; occ_n++ } }
  avg_occ=occ_n>0?sum_occ/occ_n:0; rampup_ms=(max_first-min_first)/1000
  efficiency_pct=wall_ms>0?(max_busy/1000)*100/wall_ms:0
  print "\n============================================\nHEALTH CHECK\n============================================"
  printf "  Efficiency:        %6.1f %%\n  Occupancy:         %6.1f %%\n  Ramp-up:           %6.1f ms\n", efficiency_pct, avg_occ, rampup_ms
  print "============================================\nEXECUTION SUMMARY\n============================================"
  printf "Total commands:       %d\nExecuted (P+F):       %d\nSkipped (excluded):   %d\nNo-update (skipped):  %d\nTotal time:           %d ms\nTotal exec time:      %.1f ms\nMax worker busy:      %.1f ms\nParallel factor:      %.2fx\n", cmd_count,attempted,SKIP,NOUPD,total_time,exec_ms,max_busy/1000,par_factor
  print "--------------------------------------------"
  printf "PASSED:               %d\nFAILED:               %d\nSKIPPED:              %d\nNO-UPDATE:            %d\nSuccess Rate:         %.1f%%\nAvg command time:     %.2f ms\nMin command time:     %d ms\nMax command time:     %d ms\nThroughput:           %.2f cmd/s\n", P,F,SKIP,NOUPD,success_rate,avg_dur,min_dur,max_dur,throughput
  print "============================================\nPER-ACTION STATISTICS\n============================================"
  printf "%-16s %5s %4s %4s %4s %4s  %10s %9s %9s %9s %9s %9s %9s\n","action","count","P","F","S","N","total_ms","avg_ms","min_ms","max_ms","p50_ms","p95_ms","p99_ms"
  for(k=1;k<=act_names_n;k++){ a=act_names[k]; n=act_n[a]+0
    if(n>0){ delete tmp; for(i=1;i<=n;i++) tmp[i]=act_durs[a,i]; qsort(tmp,1,n); p50=pctl(tmp,n,50); p95=pctl(tmp,n,95); p99=pctl(tmp,n,99) } else p50=p95=p99=0
    mean=n?act_sum_us[a]/n:0
    printf "%-16s %5d %4d %4d %4d %4d  %10.1f %9.1f %9.1f %9.1f %9.1f %9.1f %9.1f\n", a,act_count[a]+0,act_st[a,"P"]+0,act_st[a,"F"]+0,act_st[a,"S"]+0,act_st[a,"N"]+0,act_sum_us[a]/1000,mean/1000,act_min[a]/1000,act_max[a]/1000,p50/1000,p95/1000,p99/1000 }
  print "\n============================================\nWORKER PROFILE\n============================================"
  printf "%-4s %-8s %5s %12s %12s %7s\n","w","pid","pkgs","busy_ms","wall_ms","occ%"
  for(i=1;i<=wnum;i++){ busy=worker_busy[i]; wall=w_t_last[i]-w_t_first[i]; occ=wall>0?busy*100/wall:0
    printf "W%-3d %-8s %5d %12.1f %12.1f %7.1f\n", i-1,wpid[i],wpc[wpid[i]]+0,busy/1000,wall/1000,occ }
  if(nfail>0){ print "\n============================================\nFAILED COMMANDS: " nfail "\n============================================"
    for(i=1;i<=nfail;i++) print "  " fail_pkg[i] "|act:" fail_act[i] "|code:" fail_code[i] "|resp:" fail_msg[i] }
  print "============================================"
}'
