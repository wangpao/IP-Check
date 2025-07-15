#!/bin/bash
script_version="v2025-06-29-Final-NAT-Fix"

# --- 1. 固化的配置 ---
readonly FULL_IP=1 # 默认显示完整IP
readonly YY="cn"   # 语言固定为中文

# --- 2. 依赖检测 ---
check_and_install_dependencies(){
    if ! jq --version >/dev/null 2>&1 || ! curl --version >/dev/null 2>&1 || ! bc --version >/dev/null 2>&1 || ! dig -v >/dev/null 2>&1; then
        echo "检测到缺少依赖，将为您自动安装: jq curl bc dnsutils iproute2"
        read -p "是否继续? (y/n): " choice
        case "$choice" in
            y|Y)
                sudo apt-get update
                sudo apt-get install -y jq curl bc dnsutils iproute2
                ;;
            *) echo "脚本退出。"; exit 0;;
        esac
    fi
}
check_and_install_dependencies

# --- 颜色与字体定义 ---
Font_B="\033[1m"; Font_D="\033[2m"; Font_I="\033[3m"; Font_U="\033[4m"
Font_Red="\033[31m"; Font_Green="\033[32m"; Font_Yellow="\033[33m"; Font_Blue="\033[34m"
Font_Cyan="\033[36m"; Font_White="\033[37m"; Back_Red="\033[41m"; Back_Green="\033[42m"
Back_Yellow="\033[43m"; Font_Suffix="\033[0m"; Font_LineClear="\033[2K"; Font_LineUp="\033[1A"

# --- 全局变量 (再次精简) ---
declare IP="" IPV4="" IPV6=""
declare -A maxmind ipinfo scamalytics ipregistry ipapi abuseipdb ip2location dbip ipwhois ipdata ipqs cloudflare
declare -A tiktok disney netflix youtube amazon spotify chatgpt
declare -A sinfo shead sbasic stype sscore sfactor smedia stail
declare ibar=0 bar_pid ibar_step=0 main_pid=$$ PADDING=""
declare UA_Browser rawgithub Media_Cookie IATA_Database
# --- 核心修改：移除接口绑定，让系统自动选择路由 ---
declare CurlARG=""

# --- 3. 固定的中文语言文本 (已精简) ---
set_language(){
    sinfo[database]="正在检测IP数据库 "
    sinfo[media]="正在检测流媒体服务商 "
    sinfo[ai]="正在检测AI服务商 "
    sinfo[ldatabase]=17; sinfo[lmedia]=21; sinfo[lai]=17
    shead[title]="IP质量体检报告："
    shead[title_lite]="IP质量体检报告(Lite)："
    shead[ver]="脚本版本：$script_version"
    shead[bash]="bash my_ip_check_final.sh (个人版)"
    shead[git]="https://github.com/xykt/IPQuality (原版)"
    shead[time]=$(TZ="Asia/Shanghai" date +"报告时间：%Y-%m-%d %H:%M:%S CST")
    shead[ltitle]=16; shead[ltitle_lite]=22; shead[ptime]=$(printf '%8s' '')
    sbasic[title]="基础信息 (${Font_I}Maxmind 数据库$Font_Suffix)"
    sbasic[title_lite]="基础信息 (${Font_I}IPinfo 数据库$Font_Suffix)"
    sbasic[asn]="自治系统号：            "
    sbasic[noasn]="未分配"
    sbasic[org]="组织：                  "
    sbasic[city]="城市：                  "
    sbasic[continent]="洲际：                  "
    sbasic[timezone]="时区：                  "
    sbasic[type]="IP类型：                "
    sbasic[type0]=" 原生IP "
    sbasic[type1]=" 广播IP "
    stype[business]="   $Back_Yellow$Font_White$Font_B 商业 $Font_Suffix   "; stype[isp]="   $Back_Green$Font_White$Font_B 家宽 $Font_Suffix   "
    stype[hosting]="   $Back_Red$Font_White$Font_B 机房 $Font_Suffix   "; stype[education]="   $Back_Yellow$Font_White$Font_B 教育 $Font_Suffix   "
    stype[government]="   $Back_Yellow$Font_White$Font_B 政府 $Font_Suffix   "; stype[banking]="   $Back_Yellow$Font_White$Font_B 银行 $Font_Suffix   "
    stype[organization]="   $Back_Yellow$Font_White$Font_B 组织 $Font_Suffix   "; stype[military]="   $Back_Yellow$Font_White$Font_B 军队 $Font_Suffix   "
    stype[library]="  $Back_Yellow$Font_White$Font_B 图书馆 $Font_Suffix  "; stype[cdn]="   $Back_Red$Font_White$Font_B CDN $Font_Suffix    "
    stype[lineisp]="   $Back_Green$Font_White$Font_B 家宽 $Font_Suffix   "; stype[mobile]="   $Back_Green$Font_White$Font_B 手机 $Font_Suffix   "
    stype[spider]="   $Back_Red$Font_White$Font_B 蜘蛛 $Font_Suffix   "; stype[reserved]="   $Back_Yellow$Font_White$Font_B 保留 $Font_Suffix   "
    stype[other]="   $Back_Yellow$Font_White$Font_B 其他 $Font_Suffix   "
    stype[title]="IP类型属性"
    stype[db]="数据库：   "; stype[usetype]="使用类型： "; stype[comtype]="公司类型： "
    sscore[verylow]="$Font_Green$Font_B极低风险$Font_Suffix"; sscore[low]="$Font_Green$Font_B低风险$Font_Suffix"
    sscore[medium]="$Font_Yellow$Font_B中风险$Font_Suffix"; sscore[high]="$Font_Red$Font_B高风险$Font_Suffix"
    sscore[veryhigh]="$Font_Red$Font_B极高风险$Font_Suffix"; sscore[elevated]="$Font_Yellow$Font_B较高风险$Font_Suffix"
    sscore[suspicious]="$Font_Yellow$Font_B可疑IP$Font_Suffix"; sscore[risky]="$Font_Red$Font_B存在风险$Font_Suffix"
    sscore[highrisk]="$Font_Red$Font_B高风险$Font_Suffix"; sscore[dos]="$Font_Red$Font_B建议封禁$Font_Suffix"
    sscore[colon]="："; sscore[title]="风险评分"
    sscore[range]="$Font_Cyan风险等级：      $Font_I$Font_White$Back_Green极低         低 $Back_Yellow      中等      $Back_Red 高         极高$Font_Suffix"
    sfactor[title]="风险因子"
    sfactor[factor]="库： "; sfactor[countrycode]="地区：  "; sfactor[proxy]="代理：  "
    sfactor[tor]="Tor：   "; sfactor[vpn]="VPN：   "; sfactor[server]="服务器："; sfactor[abuser]="滥用：  "; sfactor[robot]="机器人："
    sfactor[yes]="$Font_Red$Font_B 是 $Font_Suffix"; sfactor[no]="$Font_Green$Font_B 否 $Font_Suffix"; sfactor[na]="$Font_Green$Font_B 无 $Font_Suffix"
    smedia[yes]=" $Back_Green$Font_White 解锁 $Font_Suffix  "; smedia[no]=" $Back_Red$Font_White 屏蔽 $Font_Suffix  "
    smedia[bad]=" $Back_Red$Font_White 失败 $Font_Suffix  "; smedia[pending]="$Back_Yellow$Font_White 待支持 $Font_Suffix "
    smedia[cn]=" $Back_Red$Font_White 中国 $Font_Suffix  "; smedia[noprem]="$Back_Red$Font_White 禁会员 $Font_Suffix "
    smedia[org]="$Back_Yellow$Font_White 仅自制 $Font_Suffix "; smedia[web]="$Back_Yellow$Font_White 仅网页 $Font_Suffix "
    smedia[app]=" $Back_Yellow$Font_White 仅APP $Font_Suffix "; smedia[idc]=" $Back_Yellow$Font_White 机房 $Font_Suffix  "
    smedia[native]=" $Back_Green$Font_White 原生 $Font_Suffix  "; smedia[dns]="  $Back_Yellow$Font_White DNS $Font_Suffix  "
    smedia[nodata]="         "
    smedia[title]="流媒体及AI服务解锁检测"
    smedia[meida]="服务商： "; smedia[status]="状态：   "; smedia[region]="地区：   "; smedia[type]="方式：   "
    stail[thanks]="--- 检测结束 ---" # 替换原有的感谢语
}

# --- 4. 核心检测流程 (已精简) ---
check_IP(){
    IP=$1
    local ip_type=$2 # 4 or 6
    ibar_step=0
    
    db_maxmind $ip_type
    local mode_lite=0
    if [[ $(echo "$RESPONSE"|jq '.ASN.AutonomousSystemNumber' 2>/dev/null) == "null" ]]; then
        mode_lite=1
    fi
    
    db_ipinfo
    db_scamalytics
    [[ $mode_lite -eq 0 ]] && db_ipregistry $ip_type
    db_ipapi
    [[ $mode_lite -eq 0 ]] && db_abuseipdb $ip_type
    db_ip2location $ip_type
    db_dbip
    db_ipwhois
    [[ $mode_lite -eq 0 ]] && db_ipdata $ip_type
    [[ $mode_lite -eq 0 ]] && db_ipqs $ip_type
    db_cloudflare $ip_type
    MediaUnlockTest_TikTok $ip_type
    MediaUnlockTest_DisneyPlus $ip_type
    MediaUnlockTest_Netflix $ip_type
    MediaUnlockTest_YouTube_Premium $ip_type
    MediaUnlockTest_PrimeVideo_Region $ip_type
    MediaUnlockTest_Spotify $ip_type
    OpenAITest $ip_type
    
    echo -ne "$Font_LineClear" 1>&2

    # 报告输出
    if [[ $mode_lite -eq 0 ]]; then
        show_head; show_basic; show_type; show_score; show_factor; show_media; show_tail
    else
        show_head; show_basic_lite; show_type_lite; show_score; show_factor_lite; show_media; show_tail
    fi
}

# --- 5. 报告展示函数 (已精简) ---
show_head(){
    echo -ne "\r$(printf '%72s'|tr ' ' '#')\n"
    if [[ $mode_lite -eq 0 ]];then
        calc_padding "$(printf '%*s' "${shead[ltitle]}" '')$IP" 72
        echo -ne "\r$PADDING$Font_B${shead[title]}$Font_Cyan$IP$Font_Suffix\n"
    else
        calc_padding "$(printf '%*s' "${shead[ltitle_lite]}" '')$IP" 72
        echo -ne "\r$PADDING$Font_B${shead[title_lite]}$Font_Cyan$IP$Font_Suffix\n"
    fi
    calc_padding "${shead[bash]}" 72
    echo -ne "\r$PADDING${shead[bash]}\n"
    calc_padding "${shead[git]}" 72
    echo -ne "\r$PADDING$Font_U${shead[git]}$Font_Suffix\n"
    echo -ne "\r${shead[ptime]}${shead[time]}  ${shead[ver]}\n"
    echo -ne "\r$(printf '%72s'|tr ' ' '#')\n"
}

show_basic(){
    echo -ne "\r${sbasic[title]}\n"
    if [[ -n ${maxmind[asn]} && ${maxmind[asn]} != "null" ]];then
        echo -ne "\r$Font_Cyan${sbasic[asn]}${Font_Green}AS${maxmind[asn]}$Font_Suffix\n"
        echo -ne "\r$Font_Cyan${sbasic[org]}$Font_Green${maxmind[org]}$Font_Suffix\n"
    else
        echo -ne "\r$Font_Cyan${sbasic[asn]}${sbasic[noasn]}$Font_Suffix\n"
    fi
    
    local city_info=""
    if [[ -n ${maxmind[sub]} && ${maxmind[sub]} != "null" ]]; then city_info+="${maxmind[sub]}"; fi
    if [[ -n ${maxmind[city]} && ${maxmind[city]} != "null" ]]; then [[ -n $city_info ]] && city_info+=", "; city_info+="${maxmind[city]}"; fi
    if [[ -n $city_info ]]; then echo -ne "\r$Font_Cyan${sbasic[city]}$Font_Green$city_info$Font_Suffix\n"; fi

    if [[ -n ${maxmind[countrycode]} && ${maxmind[countrycode]} != "null" ]];then
        if [[ -n ${maxmind[continentcode]} && ${maxmind[continentcode]} != "null" ]]; then
            echo -ne "\r$Font_Cyan${sbasic[continent]}$Font_Green[${maxmind[continentcode]}]${maxmind[continent]}$Font_Suffix\n"
        fi
    fi

    if [[ -n ${maxmind[timezone]} && ${maxmind[timezone]} != "null" ]]; then
        echo -ne "\r$Font_Cyan${sbasic[timezone]}$Font_Green${maxmind[timezone]}$Font_Suffix\n"
    fi
    if [[ -n ${maxmind[countrycode]} && ${maxmind[countrycode]} != "null" ]]; then
        if [ "${maxmind[countrycode]}" == "${maxmind[regcountrycode]}" ]; then
            echo -ne "\r$Font_Cyan${sbasic[type]}$Back_Green$Font_B$Font_White${sbasic[type0]}$Font_Suffix\n"
        else
            echo -ne "\r$Font_Cyan${sbasic[type]}$Back_Red$Font_B$Font_White${sbasic[type1]}$Font_Suffix\n"
        fi
    fi
}

show_basic_lite(){
    echo -ne "\r${sbasic[title_lite]}\n"
    if [[ -n ${ipinfo[asn]} && ${ipinfo[asn]} != "null" ]];then
        echo -ne "\r$Font_Cyan${sbasic[asn]}${Font_Green}AS${ipinfo[asn]}$Font_Suffix\n"
        echo -ne "\r$Font_Cyan${sbasic[org]}$Font_Green${ipinfo[org]}$Font_Suffix\n"
    else
        echo -ne "\r$Font_Cyan${sbasic[asn]}${sbasic[noasn]}$Font_Suffix\n"
    fi

    local city_info=""
    if [[ -n ${ipinfo[city]} && ${ipinfo[city]} != "null" ]]; then city_info+="${ipinfo[city]}"; fi
    if [[ -n $city_info ]]; then echo -ne "\r$Font_Cyan${sbasic[city]}$Font_Green$city_info$Font_Suffix\n"; fi

    if [[ -n ${ipinfo[continent]} && ${ipinfo[continent]} != "null" ]];then
        echo -ne "\r$Font_Cyan${sbasic[continent]}$Font_Green${ipinfo[continent]}$Font_Suffix\n"
    fi
    if [[ -n ${ipinfo[timezone]} && ${ipinfo[timezone]} != "null" ]]; then
        echo -ne "\r$Font_Cyan${sbasic[timezone]}$Font_Green${ipinfo[timezone]}$Font_Suffix\n"
    fi
    if [[ -n ${ipinfo[countrycode]} && ${ipinfo[countrycode]} != "null" ]]; then
        if [ "${ipinfo[countrycode]}" == "${ipinfo[regcountrycode]}" ]; then
            echo -ne "\r$Font_Cyan${sbasic[type]}$Back_Green$Font_B$Font_White${sbasic[type0]}$Font_Suffix\n"
        else
            echo -ne "\r$Font_Cyan${sbasic[type]}$Back_Red$Font_B$Font_White${sbasic[type1]}$Font_Suffix\n"
        fi
    fi
}

show_tail(){
    echo -ne "\r$(printf '%72s'|tr ' ' '=')\n"
    echo -ne "\r$Font_I${stail[thanks]}$Font_Suffix\n"
    echo -e ""
}

# --- 从这里开始是原脚本未改动的大量核心功能函数 ---
# VVVVVV 在此粘贴原脚本的核心函数 VVVVVV
show_progress_bar(){
show_progress_bar_ "$@" 1>&2
}
show_progress_bar_(){
local bar="\u280B\u2819\u2839\u2838\u283C\u2834\u2826\u2827\u2807\u280F"
local n=${#bar}
while sleep 0.1;do
if ! kill -0 $main_pid 2>/dev/null;then
echo -ne ""
exit
fi
echo -ne "\r$Font_Cyan$Font_B[$IP]# $1$Font_Cyan$Font_B$(printf '%*s' "$2" ''|tr ' ' '.') ${bar:ibar++*6%n:6} $(printf '%02d%%' $ibar_step) $Font_Suffix"
done
}
kill_progress_bar(){
kill "$bar_pid" 2>/dev/null&&echo -ne "\r"
}
declare -A browsers=(
[Chrome]="120.0.6087.129 121.0.6167.85 122.0.6261.39 123.0.6312.58 124.0.6367.91 125.0.6422.78"
[Firefox]="120.0.1 121.0.2 122.0.3 123.0.4 124.0.5 125.0.6")
declare -a edge_versions=(
"120.0.2210.91|120.0.6087.129"
"121.0.2277.83|121.0.6167.85"
"122.0.2345.29|122.0.6261.39"
"123.0.2403.130|123.0.6312.58"
"124.0.2478.51|124.0.6367.91"
"125.0.2535.67|125.0.6422.78")
generate_random_user_agent(){
local browsers_keys=(${!browsers[@]} "Edge")
local random_browser_index=$((RANDOM%${#browsers_keys[@]}))
local browser=${browsers_keys[random_browser_index]}
case $browser in
Chrome)local versions=(${browsers[Chrome]})
local version=${versions[RANDOM%${#versions[@]}]}
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$version Safari/537.36"
;;
Firefox)local versions=(${browsers[Firefox]})
local version=${versions[RANDOM%${#versions[@]}]}
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:${version%%.*}) Gecko/20100101 Firefox/$version"
;;
Edge)local pair=${edge_versions[RANDOM%${#edge_versions[@]}]}
local edge_ver=${pair%%|*}
local chrome_ver=${pair##*|}
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chrome_ver Safari/537.36 Edg/$edge_ver"
esac
}
adapt_locale(){
local ifunicode=$(printf '\u2800')
[[ ${#ifunicode} -gt 3 ]]&&export LC_CTYPE=en_US.UTF-8 2>/dev/null
}
check_connectivity(){
local url="https://www.google.com/generate_204"
local timeout=2
local http_code
http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "$url" 2>/dev/null)
if [[ $http_code == "204" ]];then
rawgithub="https://github.com/xykt/IPQuality/raw/"
return 0
else
rawgithub="https://testingcf.jsdelivr.net/gh/xykt/IPQuality@"
return 1
fi
}
get_ipv4(){
    local response=$(curl $CurlARG -s4 --max-time 2 myip.check.place)
    if [[ $? -eq 0 && -n "$response" ]]; then
        IPV4="$response"
    else
        IPV4=""
    fi
}
get_ipv6(){
    local response=$(curl $CurlARG -s6k --max-time 2 myip.check.place)
    if [[ $? -eq 0 && -n "$response" ]]; then
        IPV6="$response"
    else
        IPV6=""
    fi
}
calculate_display_width(){
local string="$1"
local length=0
local char
for ((i=0; i<${#string}; i++));do
char=$(echo "$string"|od -An -N1 -tx1 -j $((i))|tr -d ' ')
if [ "$(printf '%d\n' 0x$char)" -gt 127 ];then
length=$((length+2))
i=$((i+1))
else
length=$((length+1))
fi
done
echo "$length"
}
calc_padding(){
local input_text="$1"
local total_width=$2
local title_length=$(calculate_display_width "$input_text")
local left_padding=$(((total_width-title_length)/2))
if [[ $left_padding -gt 0 ]];then
PADDING=$(printf '%*s' $left_padding)
else
PADDING=""
fi
}
db_maxmind(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}Maxmind $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-8-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
maxmind=()
RESPONSE=$(curl $CurlARG -Ls -$1 -m 10 "https://ipinfo.check.place/$IP?lang=$YY")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
if [[ -z $RESPONSE ]];then
mode_lite=1
else
mode_lite=0
fi
maxmind[asn]=$(echo "$RESPONSE"|jq -r '.ASN.AutonomousSystemNumber')
maxmind[org]=$(echo "$RESPONSE"|jq -r '.ASN.AutonomousSystemOrganization')
maxmind[city]=$(echo "$RESPONSE"|jq -r '.City.Name')
maxmind[continentcode]=$(echo "$RESPONSE"|jq -r '.City.Continent.Code')
maxmind[continent]=$(echo "$RESPONSE"|jq -r '.City.Continent.Name')
maxmind[timezone]=$(echo "$RESPONSE"|jq -r '.City.Location.TimeZone')
maxmind[sub]=$(echo "$RESPONSE"|jq -r 'if .City.Subdivisions | length > 0 then .City.Subdivisions[0].Name else "N/A" end')
maxmind[countrycode]=$(echo "$RESPONSE"|jq -r '.Country.IsoCode')
maxmind[regcountrycode]=$(echo "$RESPONSE"|jq -r '.Country.RegisteredCountry.IsoCode')

# 翻译补充
if [[ $YY != "en" ]];then
    local backup_response=$(curl $CurlARG -s -$1 -m 10 "http://ipinfo.check.place/$IP?lang=en")
    [[ ${maxmind[asn]} == "null" ]]&&maxmind[asn]=$(echo "$backup_response"|jq -r '.ASN.AutonomousSystemNumber')
    [[ ${maxmind[org]} == "null" ]]&&maxmind[org]=$(echo "$backup_response"|jq -r '.ASN.AutonomousSystemOrganization')
    [[ ${maxmind[city]} == "null" ]]&&maxmind[city]=$(echo "$backup_response"|jq -r '.City.Name')
    [[ ${maxmind[continentcode]} == "null" ]]&&maxmind[continentcode]=$(echo "$backup_response"|jq -r '.City.Continent.Code')
    [[ ${maxmind[continent]} == "null" ]]&&maxmind[continent]=$(echo "$backup_response"|jq -r '.City.Continent.Name')
    [[ ${maxmind[timezone]} == "null" ]]&&maxmind[timezone]=$(echo "$backup_response"|jq -r '.City.Location.TimeZone')
    [[ ${maxmind[sub]} == "null" ]]&&maxmind[sub]=$(echo "$backup_response"|jq -r 'if .City.Subdivisions | length > 0 then .City.Subdivisions[0].Name else "N/A" end')
    [[ ${maxmind[countrycode]} == "null" ]]&&maxmind[countrycode]=$(echo "$backup_response"|jq -r '.Country.IsoCode')
    [[ ${maxmind[regcountrycode]} == "null" ]]&&maxmind[regcountrycode]=$(echo "$backup_response"|jq -r '.Country.RegisteredCountry.IsoCode')
fi
}
db_ipinfo(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}IPinfo $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-7-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
ipinfo=()
local RESPONSE=$(curl $CurlARG -Ls -m 10 "https://ipinfo.io/widget/demo/$IP")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ipinfo[usetype]=$(echo "$RESPONSE"|jq -r '.data.asn.type')
ipinfo[comtype]=$(echo "$RESPONSE"|jq -r '.data.company.type')
shopt -s nocasematch
case ${ipinfo[usetype]} in
"business")ipinfo[susetype]="${stype[business]}";;"isp")ipinfo[susetype]="${stype[isp]}";;"hosting")ipinfo[susetype]="${stype[hosting]}";;"education")ipinfo[susetype]="${stype[education]}";;*)ipinfo[susetype]="${stype[other]}";;esac
case ${ipinfo[comtype]} in
"business")ipinfo[scomtype]="${stype[business]}";;"isp")ipinfo[scomtype]="${stype[isp]}";;"hosting")ipinfo[scomtype]="${stype[hosting]}";;"education")ipinfo[scomtype]="${stype[education]}";;*)ipinfo[scomtype]="${stype[other]}";;esac
shopt -u nocasematch
ipinfo[countrycode]=$(echo "$RESPONSE"|jq -r '.data.country')
ipinfo[proxy]=$(echo "$RESPONSE"|jq -r '.data.privacy.proxy')
ipinfo[tor]=$(echo "$RESPONSE"|jq -r '.data.privacy.tor')
ipinfo[vpn]=$(echo "$RESPONSE"|jq -r '.data.privacy.vpn')
ipinfo[server]=$(echo "$RESPONSE"|jq -r '.data.privacy.hosting')
local ISO3166=$(curl -sL -m 10 "${rawgithub}main/ref/iso3166.json")
ipinfo[asn]=$(echo "$RESPONSE"|jq -r '.data.asn.asn'|sed 's/^AS//')
ipinfo[org]=$(echo "$RESPONSE"|jq -r '.data.asn.name')
ipinfo[city]=$(echo "$RESPONSE"|jq -r '.data.city')
ipinfo[timezone]=$(echo "$RESPONSE"|jq -r '.data.timezone')
ipinfo[continent]=$(echo "$ISO3166"|jq --arg code "${ipinfo[countrycode]}" -r '.[] | select(.["alpha-2"] == $code) | .region')
ipinfo[regcountrycode]=$(echo "$RESPONSE"|jq -r '.data.abuse.country')
}
db_scamalytics(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}SCAMALYTICS $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-12-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
scamalytics=()
local RESPONSE=$(curl $CurlARG --user-agent "$UA_Browser" -sL -H "Referer: https://scamalytics.com" -m 10 "https://scamalytics.com/ip/$IP")
[[ -z $RESPONSE ]]&&return 1
local tmpscore=$(echo "$RESPONSE"|grep -oE 'Fraud Score: [0-9]+'|awk -F': ' '{print $2}')
scamalytics[score]=$(echo "$tmpscore"|bc)
if [[ ${scamalytics[score]} -lt 25 ]];then scamalytics[risk]="${sscore[low]}"; elif [[ ${scamalytics[score]} -lt 50 ]];then scamalytics[risk]="${sscore[medium]}"; elif [[ ${scamalytics[score]} -lt 75 ]];then scamalytics[risk]="${sscore[high]}"; elif [[ ${scamalytics[score]} -ge 75 ]];then scamalytics[risk]="${sscore[veryhigh]}"; fi
scamalytics[countrycode]=$(echo "$RESPONSE"|awk -F'</?td>' '/<th>Country Code<\/th>/ {getline; print $2}')
scamalytics[vpn]=$(echo "$RESPONSE"|awk '/<th>Anonymizing VPN<\/th>/ {getline; getline; if ($0 ~ /Yes/) print "true"; else print "false"}')
scamalytics[tor]=$(echo "$RESPONSE"|awk '/<th>Tor Exit Node<\/th>/ {getline; getline; if ($0 ~ /Yes/) print "true"; else print "false"}')
scamalytics[server]=$(echo "$RESPONSE"|awk '/<th>Server<\/th>/ {getline; getline; if ($0 ~ /Yes/) print "true"; else print "false"}')
scamalytics[proxy1]=$(echo "$RESPONSE"|awk '/<th>Public Proxy<\/th>/ {getline; getline; if ($0 ~ /Yes/) print "true"; else print "false"}')
scamalytics[proxy2]=$(echo "$RESPONSE"|awk '/<th>Web Proxy<\/th>/ {getline; getline; if ($0 ~ /Yes/) print "true"; else print "false"}')
[[ ${scamalytics[proxy1]} == "true" || ${scamalytics[proxy2]} == "true" ]]&&scamalytics[proxy]="true"
[[ ${scamalytics[proxy1]} == "false" && ${scamalytics[proxy2]} == "false" ]]&&scamalytics[proxy]="false"
scamalytics[robot]=$(echo "$RESPONSE"|awk '/<th>Search Engine Robot<\/th>/ {getline; getline; if ($0 ~ /Yes/) print "true"; else print "false"}')
}
db_ipregistry(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}ipregistry $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-11-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
ipregistry=()
local RESPONSE=$(curl $CurlARG -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=ipregistry")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ipregistry[usetype]=$(echo "$RESPONSE"|jq -r '.connection.type')
ipregistry[comtype]=$(echo "$RESPONSE"|jq -r '.company.type')
shopt -s nocasematch
case ${ipregistry[usetype]} in
"business")ipregistry[susetype]="${stype[business]}";;"isp")ipregistry[susetype]="${stype[isp]}";;"hosting")ipregistry[susetype]="${stype[hosting]}";;"education")ipregistry[susetype]="${stype[education]}";;"government")ipregistry[susetype]="${stype[government]}";;*)ipregistry[susetype]="${stype[other]}";;esac
case ${ipregistry[comtype]} in
"business")ipregistry[scomtype]="${stype[business]}";;"isp")ipregistry[scomtype]="${stype[isp]}";;"hosting")ipregistry[scomtype]="${stype[hosting]}";;"education")ipregistry[scomtype]="${stype[education]}";;"government")ipregistry[scomtype]="${stype[government]}";;*)ipregistry[scomtype]="${stype[other]}";;esac
shopt -u nocasematch
ipregistry[countrycode]=$(echo "$RESPONSE"|jq -r '.location.country.code')
ipregistry[proxy]=$(echo "$RESPONSE"|jq -r '.security.is_proxy')
ipregistry[tor1]=$(echo "$RESPONSE"|jq -r '.security.is_tor'); ipregistry[tor2]=$(echo "$RESPONSE"|jq -r '.security.is_tor_exit')
[[ ${ipregistry[tor1]} == "true" || ${ipregistry[tor2]} == "true" ]]&&ipregistry[tor]="true"; [[ ${ipregistry[tor1]} == "false" && ${ipregistry[tor2]} == "false" ]]&&ipregistry[tor]="false"
ipregistry[vpn]=$(echo "$RESPONSE"|jq -r '.security.is_vpn')
ipregistry[server]=$(echo "$RESPONSE"|jq -r '.security.is_cloud_provider')
ipregistry[abuser]=$(echo "$RESPONSE"|jq -r '.security.is_abuser')
}
db_ipapi(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}ipapi $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-6-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
ipapi=()
local RESPONSE=$(curl $CurlARG -sL -m 10 "https://api.ipapi.is/?q=$IP")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ipapi[usetype]=$(echo "$RESPONSE"|jq -r '.asn.type'); ipapi[comtype]=$(echo "$RESPONSE"|jq -r '.company.type')
shopt -s nocasematch
case ${ipapi[usetype]} in
"business")ipapi[susetype]="${stype[business]}";;"isp")ipapi[susetype]="${stype[isp]}";;"hosting")ipapi[susetype]="${stype[hosting]}";;"education")ipapi[susetype]="${stype[education]}";;"government")ipapi[susetype]="${stype[government]}";;"banking")ipapi[susetype]="${stype[banking]}";;*)ipapi[susetype]="${stype[other]}";;esac
case ${ipapi[comtype]} in
"business")ipapi[scomtype]="${stype[business]}";;"isp")ipapi[scomtype]="${stype[isp]}";;"hosting")ipapi[scomtype]="${stype[hosting]}";;"education")ipapi[scomtype]="${stype[education]}";;"government")ipapi[scomtype]="${stype[government]}";;"banking")ipapi[scomtype]="${stype[banking]}";;*)ipapi[scomtype]="${stype[other]}";;esac
[[ -z $RESPONSE ]]&&return 1
ipapi[scoretext]=$(echo "$RESPONSE"|jq -r '.company.abuser_score'); ipapi[scorenum]=$(echo "${ipapi[scoretext]}"|awk '{print $1}')
ipapi[risktext]=$(echo "${ipapi[scoretext]}"|awk -F'[()]' '{print $2}'); ipapi[score]=$(awk "BEGIN {printf \"%.2f%%\", ${ipapi[scorenum]} * 100}")
case ${ipapi[risktext]} in
"Very Low")ipapi[risk]="${sscore[verylow]}";;"Low")ipapi[risk]="${sscore[low]}";;"Elevated")ipapi[risk]="${sscore[elevated]}";;"High")ipapi[risk]="${sscore[high]}";;"Very High")ipapi[risk]="${sscore[veryhigh]}";;esac
shopt -u nocasematch
ipapi[countrycode]=$(echo "$RESPONSE"|jq -r '.location.country_code'); ipapi[proxy]=$(echo "$RESPONSE"|jq -r '.is_proxy'); ipapi[tor]=$(echo "$RESPONSE"|jq -r '.is_tor'); ipapi[vpn]=$(echo "$RESPONSE"|jq -r '.is_vpn'); ipapi[server]=$(echo "$RESPONSE"|jq -r '.is_datacenter'); ipapi[abuser]=$(echo "$RESPONSE"|jq -r '.is_abuser'); ipapi[robot]=$(echo "$RESPONSE"|jq -r '.is_crawler')
}
db_abuseipdb(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}AbuseIPDB $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-10-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
abuseipdb=()
local RESPONSE=$(curl $CurlARG -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=abuseipdb")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
abuseipdb[usetype]=$(echo "$RESPONSE"|jq -r '.data.usageType')
shopt -s nocasematch
case ${abuseipdb[usetype]} in
"Commercial")abuseipdb[susetype]="${stype[business]}";;"Data Center/Web Hosting/Transit")abuseipdb[susetype]="${stype[hosting]}";;"University/College/School")abuseipdb[susetype]="${stype[education]}";;"Government")abuseipdb[susetype]="${stype[government]}";;"banking")abuseipdb[susetype]="${stype[banking]}";;"Organization")abuseipdb[susetype]="${stype[organization]}";;"Military")abuseipdb[susetype]="${stype[military]}";;"Library")abuseipdb[susetype]="${stype[library]}";;"Content Delivery Network")abuseipdb[susetype]="${stype[cdn]}";;"Fixed Line ISP")abuseipdb[susetype]="${stype[lineisp]}";;"Mobile ISP")abuseipdb[susetype]="${stype[mobile]}";;"Search Engine Spider")abuseipdb[susetype]="${stype[spider]}";;"Reserved")abuseipdb[susetype]="${stype[reserved]}";;*)abuseipdb[susetype]="${stype[other]}";;esac
shopt -u nocasematch
abuseipdb[score]=$(echo "$RESPONSE"|jq -r '.data.abuseConfidenceScore')
if [[ ${abuseipdb[score]} -lt 25 ]];then abuseipdb[risk]="${sscore[low]}"; elif [[ ${abuseipdb[score]} -lt 75 ]];then abuseipdb[risk]="${sscore[high]}"; elif [[ ${abuseipdb[score]} -ge 75 ]];then abuseipdb[risk]="${sscore[dos]}"; fi
}
db_ip2location(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}IP2LOCATION $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-12-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
ip2location=()
local RESPONSE=$(curl $CurlARG -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=ip2location")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ip2location[usetype]=$(echo "$RESPONSE"|jq -r '.usage_type'); shopt -s nocasematch; local first_use="${ip2location[usetype]%%/*}"
case $first_use in
"COM")ip2location[susetype]="${stype[business]}";;"DCH")ip2location[susetype]="${stype[hosting]}";;"EDU")ip2location[susetype]="${stype[education]}";;"GOV")ip2location[susetype]="${stype[government]}";;"ORG")ip2location[susetype]="${stype[organization]}";;"MIL")ip2location[susetype]="${stype[military]}";;"LIB")ip2location[susetype]="${stype[library]}";;"CDN")ip2location[susetype]="${stype[cdn]}";;"ISP")ip2location[susetype]="${stype[lineisp]}";;"MOB")ip2location[susetype]="${stype[mobile]}";;"SES")ip2location[susetype]="${stype[spider]}";;"RSV")ip2location[susetype]="${stype[reserved]}";;*)ip2location[susetype]="${stype[other]}";;esac
shopt -u nocasematch
ip2location[countrycode]=$(echo "$RESPONSE"|jq -r '.country_code'); ip2location[proxy1]=$(echo "$RESPONSE"|jq -r '.proxy.is_public_proxy'); ip2location[proxy2]=$(echo "$RESPONSE"|jq -r '.proxy.is_web_proxy')
[[ ${ip2location[proxy1]} == "true" || ${ip2location[proxy2]} == "true" ]]&&ip2location[proxy]="true"; [[ ${ip2location[proxy1]} == "false" && ${ip2location[proxy2]} == "false" ]]&&ip2location[proxy]="false"
ip2location[tor]=$(echo "$RESPONSE"|jq -r '.proxy.is_tor'); ip2location[vpn]=$(echo "$RESPONSE"|jq -r '.proxy.is_vpn'); ip2location[server]=$(echo "$RESPONSE"|jq -r '.proxy.is_data_center'); ip2location[abuser]=$(echo "$RESPONSE"|jq -r '.proxy.is_spammer')
ip2location[robot1]=$(echo "$RESPONSE"|jq -r '.proxy.is_web_crawler'); ip2location[robot2]=$(echo "$RESPONSE"|jq -r '.proxy.is_scanner'); ip2location[robot3]=$(echo "$RESPONSE"|jq -r '.proxy.is_botnet')
[[ ${ip2location[robot1]} == "true" || ${ip2location[robot2]} == "true" || ${ip2location[robot3]} == "true" ]]&&ip2location[robot]="true"; [[ ${ip2location[robot1]} == "false" && ${ip2location[robot2]} == "false" && ${ip2location[robot3]} == "false" ]]&&ip2location[robot]="false"
}
db_dbip(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}DB-IP $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-6-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
dbip=(); local RESPONSE=$(curl $CurlARG -sL -m 10 "https://db-ip.com/demo/home.php?s=$IP")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""; dbip[risktext]=$(echo "$RESPONSE"|jq -r '.demoInfo.threatLevel')
shopt -s nocasematch; case ${dbip[risktext]} in "low")dbip[risk]="${sscore[low]}";dbip[score]=0;; "medium")dbip[risk]="${sscore[medium]}";dbip[score]=50;; "high")dbip[risk]="${sscore[high]}";dbip[score]=100;; esac; shopt -u nocasematch
}
db_ipwhois(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}IPWHOIS $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-8-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
ipwhois=()
local RESPONSE=$(curl $CurlARG -sL -m 10 "https://ipwhois.io/widget?ip=$IP&lang=en" --compressed -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0" -H "Referer: https://ipwhois.io/")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ipwhois[countrycode]=$(echo "$RESPONSE"|jq -r '.country_code'); ipwhois[proxy]=$(echo "$RESPONSE"|jq -r '.security.proxy'); ipwhois[tor]=$(echo "$RESPONSE"|jq -r '.security.tor'); ipwhois[vpn]=$(echo "$RESPONSE"|jq -r '.security.vpn'); ipwhois[server]=$(echo "$RESPONSE"|jq -r '.security.hosting')
}
db_ipdata(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}ipdata $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-7-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
ipdata=()
local RESPONSE=$(curl $CurlARG -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=ipdata")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ipdata[countrycode]=$(echo "$RESPONSE"|jq -r '.country_code'); ipdata[proxy]=$(echo "$RESPONSE"|jq -r '.threat.is_proxy'); ipdata[tor]=$(echo "$RESPONSE"|jq -r '.threat.is_tor'); ipdata[server]=$(echo "$RESPONSE"|jq -r '.threat.is_datacenter')
ipdata[abuser1]=$(echo "$RESPONSE"|jq -r '.threat.is_threat'); ipdata[abuser2]=$(echo "$RESPONSE"|jq -r '.threat.is_known_abuser'); ipdata[abuser3]=$(echo "$RESPONSE"|jq -r '.threat.is_known_attacker')
[[ ${ipdata[abuser1]} == "true" || ${ipdata[abuser2]} == "true" || ${ipdata[abuser3]} == "true" ]]&&ipdata[abuser]="true"; [[ ${ipdata[abuser1]} == "false" && ${ipdata[abuser2]} == "false" && ${ipdata[abuser3]} == "false" ]]&&ipdata[abuser]="false"
}
db_ipqs(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}IPQS $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-5-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
ipqs=()
local RESPONSE=$(curl $CurlARG -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=ipqualityscore")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ipqs[score]=$(echo "$RESPONSE"|jq -r '.fraud_score')
if [[ ${ipqs[score]} -lt 75 ]];then ipqs[risk]="${sscore[low]}"; elif [[ ${ipqs[score]} -lt 85 ]];then ipqs[risk]="${sscore[suspicious]}"; elif [[ ${ipqs[score]} -lt 90 ]];then ipqs[risk]="${sscore[risky]}"; elif [[ ${ipqs[score]} -ge 90 ]];then ipqs[risk]="${sscore[highrisk]}"; fi
ipqs[countrycode]=$(echo "$RESPONSE"|jq -r '.country_code'); ipqs[proxy]=$(echo "$RESPONSE"|jq -r '.proxy'); ipqs[tor]=$(echo "$RESPONSE"|jq -r '.tor'); ipqs[vpn]=$(echo "$RESPONSE"|jq -r '.vpn'); ipqs[abuser]=$(echo "$RESPONSE"|jq -r '.recent_abuse'); ipqs[robot]=$(echo "$RESPONSE"|jq -r '.bot_status')
}
db_cloudflare(){
local temp_info="$Font_Cyan$Font_B${sinfo[database]}${Font_I}Cloudflare $Font_Suffix"
((ibar_step+=3))
show_progress_bar "$temp_info" $((40-11-${sinfo[ldatabase]}))&
bar_pid="$!"&&disown "$bar_pid"
trap "kill_progress_bar" RETURN
cloudflare=()
local RESPONSE=$(curl $CurlARG -sL -$1 -m 10 "https://ip.nodeget.com/json")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
cloudflare[score]=$(echo "$RESPONSE"|jq -r '.ip.riskScore')
if [[ ${cloudflare[score]} -lt 10 ]];then cloudflare[risk]="${sscore[low]}"; elif [[ ${cloudflare[score]} -lt 15 ]];then cloudflare[risk]="${sscore[medium]}"; elif [[ ${cloudflare[score]} -lt 25 ]];then cloudflare[risk]="${sscore[risky]}"; elif [[ ${cloudflare[score]} -ge 50 ]];then cloudflare[risk]="${sscore[veryhigh]}"; fi
}
Check_DNS_1(){
local resultdns=$(nslookup $1); local resultinlines=(${resultdns//$'\n'/ }); local resultindex=0; for i in ${resultinlines[*]};do if [[ $i == "Name:" ]];then local resultdnsindex=$((resultindex+3)); break; fi; resultindex=$((resultindex+1)); done; echo $(Check_DNS_IP ${resultinlines[$resultdnsindex]} ${resultinlines[1]})
}
Check_DNS_2(){
local resultdnstext=$(dig $1|grep "ANSWER:"); local resultdnstext=${resultdnstext#*"ANSWER: "}; local resultdnstext=${resultdnstext%", AUTHORITY:"*}; if [ "$resultdnstext" == "0" ]||[ "$resultdnstext" == "1" ]||[ "$resultdnstext" == "2" ];then echo 0; else echo 1; fi
}
Check_DNS_3(){
local resultdnstext=$(dig "test$RANDOM$RANDOM.$1"|grep "ANSWER:"); local resultdnstext=${resultdnstext#*"ANSWER: "}; local resultdnstext=${resultdnstext%", AUTHORITY:"*}; if [ "$resultdnstext" == "0" ];then echo 1; else echo 0; fi
}
Check_DNS_IP(){
if [ "$1" != "${1#*[0-9].[0-9]}" ];then
if [ "$(calc_ip_net "$1" 255.0.0.0)" == "10.0.0.0" ];then echo 0; elif [ "$(calc_ip_net "$1" 255.240.0.0)" == "172.16.0.0" ];then echo 0; elif [ "$(calc_ip_net "$1" 255.255.0.0)" == "169.254.0.0" ];then echo 0; elif [ "$(calc_ip_net "$1" 255.255.0.0)" == "192.168.0.0" ];then echo 0; elif [ "$(calc_ip_net "$1" 255.255.255.0)" == "$(calc_ip_net "$2" 255.255.255.0)" ];then echo 0; else echo 1; fi
elif [ "$1" != "${1#*[0-9a-fA-F]:*}" ];then
if [ "${1:0:3}" == "fe8" ] || [ "${1:0:3}" == "FE8" ] || [ "${1:0:2}" == "fc" ] || [ "${1:0:2}" == "FC" ] || [ "${1:0:2}" == "fd" ] || [ "${1:0:2}" == "FD" ] || [ "${1:0:2}" == "ff" ] || [ "${1:0:2}" == "FF" ];then echo 0; else echo 1; fi
else echo 0; fi
}
calc_ip_net(){
sip="$1"; snetmask="$2"; local ipFIELD1=$(echo "$sip"|cut -d. -f1); local ipFIELD2=$(echo "$sip"|cut -d. -f2); local ipFIELD3=$(echo "$sip"|cut -d. -f3); local ipFIELD4=$(echo "$sip"|cut -d. -f4); local netmaskFIELD1=$(echo "$snetmask"|cut -d. -f1); local netmaskFIELD2=$(echo "$snetmask"|cut -d. -f2); local netmaskFIELD3=$(echo "$snetmask"|cut -d. -f3); local netmaskFIELD4=$(echo "$snetmask"|cut -d. -f4); echo "$((ipFIELD1&netmaskFIELD1)).$((ipFIELD2&netmaskFIELD2)).$((ipFIELD3&netmaskFIELD3)).$((ipFIELD4&netmaskFIELD4))"
}
Get_Unlock_Type(){
while [ $# -ne 0 ];do if [ "$1" = "0" ];then echo "${smedia[dns]}"; return; fi; shift; done; echo "${smedia[native]}"
}
MediaUnlockTest_TikTok(){
local temp_info="$Font_Cyan$Font_B${sinfo[media]}${Font_I}TikTok $Font_Suffix"; ((ibar_step+=3)); show_progress_bar "$temp_info" $((40-7-${sinfo[lmedia]}))& bar_pid="$!"&&disown "$bar_pid"; trap "kill_progress_bar" RETURN; tiktok=(); local checkunlockurl="tiktok.com"; local result1=$(Check_DNS_1 $checkunlockurl); local result3=$(Check_DNS_3 $checkunlockurl); local resultunlocktype=$(Get_Unlock_Type $result1 $result3); local Ftmpresult=$(curl $CurlARG -$1 --user-agent "$UA_Browser" -sL -m 10 "https://www.tiktok.com/"); if [[ $Ftmpresult == "curl"* ]];then tiktok[ustatus]="${smedia[no]}"; tiktok[uregion]="${smedia[nodata]}"; tiktok[utype]="${smedia[nodata]}"; return; fi; local FRegion=$(echo $Ftmpresult|grep '"region":'|sed 's/.*"region"//'|cut -f2 -d'"'); if [ -n "$FRegion" ];then tiktok[ustatus]="${smedia[yes]}"; tiktok[uregion]="  [$FRegion]   "; tiktok[utype]="$resultunlocktype"; return; fi; local STmpresult=$(curl $CurlARG -$1 --user-agent "$UA_Browser" -sL -m 10 -H "Accept-Encoding: gzip" "https://www.tiktok.com"|gunzip 2>/dev/null); local SRegion=$(echo $STmpresult|grep '"region":'|sed 's/.*"region"//'|cut -f2 -d'"'); if [ -n "$SRegion" ];then tiktok[ustatus]="${smedia[idc]}"; tiktok[uregion]="  [$SRegion]   "; tiktok[utype]="$resultunlocktype"; return; else tiktok[ustatus]="${smedia[bad]}"; tiktok[uregion]="${smedia[nodata]}"; tiktok[utype]="${smedia[nodata]}"; return; fi
}
MediaUnlockTest_DisneyPlus(){
local temp_info="$Font_Cyan$Font_B${sinfo[media]}${Font_I}Disney+ $Font_Suffix"; ((ibar_step+=3)); show_progress_bar "$temp_info" $((40-8-${sinfo[lmedia]}))& bar_pid="$!"&&disown "$bar_pid"; trap "kill_progress_bar" RETURN; disney=(); local checkunlockurl="disneyplus.com"; local result1=$(Check_DNS_1 $checkunlockurl); local result3=$(Check_DNS_3 $checkunlockurl); local resultunlocktype=$(Get_Unlock_Type $result1 $result3); local PreAssertion=$(curl $CurlARG -$1 --user-agent "$UA_Browser" -s --max-time 10 -X POST "https://disney.api.edge.bamgrid.com/devices" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -H "content-type: application/json; charset=UTF-8" -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' 2>&1); if [[ $PreAssertion == "curl"* ]];then disney[ustatus]="${smedia[bad]}"; disney[uregion]="${smedia[nodata]}"; disney[utype]="${smedia[nodata]}"; return; fi; local assertion=$(echo $PreAssertion|jq -r '.assertion' 2>/dev/null); local PreDisneyCookie=$(echo "$Media_Cookie"|sed -n '1p'); local disneycookie=$(echo $PreDisneyCookie|sed "s/DISNEYASSERTION/$assertion/g"); local TokenContent=$(curl $CurlARG -$1 --user-agent "$UA_Browser" -s --max-time 10 -X POST "https://disney.api.edge.bamgrid.com/token" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycookie" 2>&1); if [ -n "$(echo $TokenContent|jq -r 'select(.error_description == "forbidden-location") | .error_description' 2>/dev/null)" ]||[ -n "$(echo $TokenContent|grep '403 ERROR')" ];then disney[ustatus]="${smedia[no]}"; disney[uregion]="${smedia[nodata]}"; disney[utype]="${smedia[nodata]}"; return; fi; local fakecontent=$(echo "$Media_Cookie"|sed -n '8p'); local refreshToken=$(echo $TokenContent|jq -r '.refresh_token' 2>/dev/null); local disneycontent=$(echo $fakecontent|sed "s/ILOVEDISNEY/$refreshToken/g"); local tmpresult=$(curl $CurlARG -$1 --user-agent "$UA_Browser" -X POST -sSL --max-time 10 "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql" -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycontent" 2>&1); local region=$(echo $tmpresult|jq -r '.extensions.sdk.session.location.countryCode' 2>/dev/null); local inSupportedLocation=$(echo $tmpresult|jq -r '.extensions.sdk.session.inSupportedLocation' 2>/dev/null); if [ -n "$region" ]&&[[ $inSupportedLocation == "true" ]];then disney[ustatus]="${smedia[yes]}"; disney[uregion]="  [$region]   "; disney[utype]="$resultunlocktype"; else disney[ustatus]="${smedia[no]}"; disney[uregion]="${smedia[nodata]}"; disney[utype]="${smedia[nodata]}"; fi
}
MediaUnlockTest_Netflix(){
local temp_info="$Font_Cyan$Font_B${sinfo[media]}${Font_I}Netflix $Font_Suffix"; ((ibar_step+=3)); show_progress_bar "$temp_info" $((40-8-${sinfo[lmedia]}))& bar_pid="$!"&&disown "$bar_pid"; trap "kill_progress_bar" RETURN; netflix=(); local checkunlockurl="netflix.com"; local result1=$(Check_DNS_1 $checkunlockurl); local result2=$(Check_DNS_2 $checkunlockurl); local result3=$(Check_DNS_3 $checkunlockurl); local resultunlocktype=$(Get_Unlock_Type $result1 $result2 $result3); local result1=$(curl $CurlARG -$1 --user-agent "$UA_Browser" -fsLI -X GET --write-out %{http_code} --output /dev/null --max-time 10 --tlsv1.3 "https://www.netflix.com/title/81280792" 2>&1); local result2=$(curl $CurlARG -$1 --user-agent "$UA_Browser" -fsLI -X GET --write-out %{http_code} --output /dev/null --max-time 10 --tlsv1.3 "https://www.netflix.com/title/70143836" 2>&1); local regiontmp=$(curl $CurlARG -$1 --user-agent "$UA_Browser" -fSsI -X GET --max-time 10 --write-out %{redirect_url} --output /dev/null --tlsv1.3 "https://www.netflix.com/login" 2>&1); if [[ $regiontmp == "curl"* ]];then netflix[ustatus]="${smedia[bad]}"; netflix[uregion]="${smedia[nodata]}"; netflix[utype]="${smedia[nodata]}"; return; fi; local region=$(echo $regiontmp|cut -d '/' -f4|cut -d '-' -f1|tr [:lower:] [:upper:]); if [[ -z $region ]];then region="US"; fi; if [[ $result1 == "404" ]]&&[[ $result2 == "404" ]];then netflix[ustatus]="${smedia[org]}"; netflix[uregion]="  [$region]   "; netflix[utype]="$resultunlocktype"; elif [[ $result1 == "403" ]]&&[[ $result2 == "403" ]];then netflix[ustatus]="${smedia[no]}"; netflix[uregion]="${smedia[nodata]}"; netflix[utype]="${smedia[nodata]}"; elif [[ $result1 == "200" ]]||[[ $result2 == "200" ]];then netflix[ustatus]="${smedia[yes]}"; netflix[uregion]="  [$region]   "; netflix[utype]="$resultunlocktype"; else netflix[ustatus]="${smedia[bad]}"; netflix[uregion]="${smedia[nodata]}"; netflix[utype]="${smedia[nodata]}"; fi
}
MediaUnlockTest_YouTube_Premium(){
local temp_info="$Font_Cyan$Font_B${sinfo[media]}${Font_I}Youtube $Font_Suffix"; ((ibar_step+=3)); show_progress_bar "$temp_info" $((40-8-${sinfo[lmedia]}))& bar_pid="$!"&&disown "$bar_pid"; trap "kill_progress_bar" RETURN; youtube=(); local checkunlockurl="www.youtube.com"; local result1=$(Check_DNS_1 $checkunlockurl); local result3=$(Check_DNS_3 $checkunlockurl); local resultunlocktype=$(Get_Unlock_Type $result1 $result3); local tmpresult=$(curl $CurlARG -$1 --max-time 10 -sSL -H "Accept-Language: en" "https://www.youtube.com/premium" 2>&1); if [[ $tmpresult == "curl"* ]];then youtube[ustatus]="${smedia[bad]}"; youtube[uregion]="${smedia[nodata]}"; youtube[utype]="${smedia[nodata]}"; return; fi; if [ -n "$(echo $tmpresult|grep 'www.google.cn')" ];then youtube[ustatus]="${smedia[cn]}"; youtube[uregion]="  $Font_Red[CN]$Font_Green   "; youtube[utype]="${smedia[nodata]}"; return; fi; local region=$(echo $tmpresult|sed -n 's/.*"contentRegion":"\([^"]*\)".*/\1/p'); if [ -n "$(echo $tmpresult|grep 'Premium is not available in your country')" ];then youtube[ustatus]="${smedia[noprem]}"; youtube[uregion]="${smedia[nodata]}"; youtube[utype]="$resultunlocktype"; elif [ -n "$(echo $tmpresult|grep 'ad-free')" ];then youtube[ustatus]="${smedia[yes]}"; youtube[uregion]="  [$region]   "; youtube[utype]="$resultunlocktype"; else youtube[ustatus]="${smedia[bad]}"; youtube[uregion]="${smedia[nodata]}"; youtube[utype]="${smedia[nodata]}"; fi
}
MediaUnlockTest_PrimeVideo_Region(){
local temp_info="$Font_Cyan$Font_B${sinfo[media]}${Font_I}Amazon $Font_Suffix"; ((ibar_step+=3)); show_progress_bar "$temp_info" $((40-7-${sinfo[lmedia]}))& bar_pid="$!"&&disown "$bar_pid"; trap "kill_progress_bar" RETURN; amazon=(); local checkunlockurl="www.primevideo.com"; local result1=$(Check_DNS_1 $checkunlockurl); local result3=$(Check_DNS_3 $checkunlockurl); local resultunlocktype=$(Get_Unlock_Type $result1 $result3); local tmpresult=$(curl $CurlARG -$1 --user-agent "$UA_Browser" -sL --max-time 10 "https://www.primevideo.com" 2>&1); if [[ $tmpresult == "curl"* ]];then amazon[ustatus]="${smedia[bad]}"; amazon[uregion]="${smedia[nodata]}"; amazon[utype]="${smedia[nodata]}"; return; fi; local result=$(echo $tmpresult|grep '"currentTerritory":'|sed 's/.*currentTerritory//'|cut -f3 -d'"'|head -n 1); if [ -n "$result" ];then amazon[ustatus]="${smedia[yes]}"; amazon[uregion]="  [$result]   "; amazon[utype]="$resultunlocktype"; else amazon[ustatus]="${smedia[no]}"; amazon[uregion]="${smedia[nodata]}"; amazon[utype]="${smedia[nodata]}"; fi
}
MediaUnlockTest_Spotify(){
local temp_info="$Font_Cyan$Font_B${sinfo[media]}${Font_I}Spotify $Font_Suffix"; ((ibar_step+=3)); show_progress_bar "$temp_info" $((40-8-${sinfo[lmedia]}))& bar_pid="$!"&&disown "$bar_pid"; trap "kill_progress_bar" RETURN; spotify=(); local checkunlockurl="spclient.wg.spotify.com"; local result1=$(Check_DNS_1 $checkunlockurl); local result3=$(Check_DNS_3 $checkunlockurl); local resultunlocktype=$(Get_Unlock_Type $result1 $result3); local tmpresult=$(curl $CurlARG -$1 --user-agent "$UA_Browser" -s --max-time 10 -X POST "https://spclient.wg.spotify.com/signup/public/v1/account" -d "birth_day=11&birth_month=11&birth_year=2000&collect_personal_info=undefined&creation_flow=&creation_point=https%3A%2F%2Fwww.spotify.com%2Fhk-en%2F&displayname=Gay%20Lord&gender=male&iagree=1&key=a1e486e2729f46d6bb368d6b2bcda326&platform=www&referrer=&send-email=0&thirdpartyemail=0&identifier_token=AgE6YTvEzkReHNfJpO114514" -H "Accept-Language: en" 2>&1); if echo "$tmpresult"|jq . >/dev/null 2>&1;then local region=$(echo $tmpresult|jq -r '.country'); local StatusCode=$(echo $tmpresult|jq -r '.status'); if [ "$StatusCode" = "120" ];then spotify[ustatus]="${smedia[no]}"; spotify[uregion]="${smedia[nodata]}"; spotify[utype]="${smedia[nodata]}"; elif [ -n "$region" ];then spotify[ustatus]="${smedia[yes]}"; spotify[uregion]="  [$region]   "; spotify[utype]="$resultunlocktype"; else spotify[ustatus]="${smedia[bad]}"; spotify[uregion]="${smedia[nodata]}"; spotify[utype]="${smedia[nodata]}"; fi; else spotify[ustatus]="${smedia[bad]}"; spotify[uregion]="${smedia[nodata]}"; spotify[utype]="${smedia[nodata]}"; fi
}
OpenAITest(){
local temp_info="$Font_Cyan$Font_B${sinfo[ai]}${Font_I}ChatGPT $Font_Suffix"; ((ibar_step+=3)); show_progress_bar "$temp_info" $((40-8-${sinfo[lai]}))& bar_pid="$!"&&disown "$bar_pid"; trap "kill_progress_bar" RETURN; chatgpt=(); local checkunlockurl="chat.openai.com"; local result1=$(Check_DNS_1 $checkunlockurl); local result2=$(Check_DNS_2 $checkunlockurl); local result3=$(Check_DNS_3 $checkunlockurl); local checkunlockurl="ios.chat.openai.com"; local result4=$(Check_DNS_1 $checkunlockurl); local result5=$(Check_DNS_2 $checkunlockurl); local result6=$(Check_DNS_3 $checkunlockurl); local checkunlockurl="api.openai.com"; local result7=$(Check_DNS_1 $checkunlockurl); local result8=$(Check_DNS_3 $checkunlockurl); local resultunlocktype=$(Get_Unlock_Type $result1 $result2 $result3 $result4 $result5 $result6 $result7 $result8); local tmpresult1=$(curl $CurlARG -$1 -sS --max-time 10 'https://api.openai.com/compliance/cookie_requirements' -H 'origin: https://platform.openai.com' -H 'referer: https://platform.openai.com/' 2>&1); local tmpresult2=$(curl $CurlARG -$1 -sS --max-time 10 'https://ios.chat.openai.com/' 2>&1); local result1=$(echo $tmpresult1|grep unsupported_country); local result2=$(echo $tmpresult2|grep VPN); local countryCode="$(curl $CurlARG --max-time 10 -sS https://chat.openai.com/cdn-cgi/trace 2>&1|grep "loc="|awk -F= '{print $2}')"; if [ -z "$result2" ]&&[ -z "$result1" ]&&[[ $tmpresult1 != "curl"* ]]&&[[ $tmpresult2 != "curl"* ]];then chatgpt[ustatus]="${smedia[yes]}"; chatgpt[uregion]="  [$countryCode]   "; chatgpt[utype]="$resultunlocktype"; elif [ -n "$result2" ]&&[ -n "$result1" ];then chatgpt[ustatus]="${smedia[no]}"; chatgpt[uregion]="${smedia[nodata]}"; chatgpt[utype]="${smedia[nodata]}"; elif [ -z "$result1" ]&&[ -n "$result2" ]&&[[ $tmpresult1 != "curl"* ]];then chatgpt[ustatus]="${smedia[web]}"; chatgpt[uregion]="  [$countryCode]   "; chatgpt[utype]="$resultunlocktype"; elif [ -n "$result1" ]&&[ -z "$result2" ];then chatgpt[ustatus]="${smedia[app]}"; chatgpt[uregion]="  [$countryCode]   "; chatgpt[utype]="$resultunlocktype"; else chatgpt[ustatus]="${smedia[bad]}"; chatgpt[uregion]="${smedia[nodata]}"; chatgpt[utype]="${smedia[nodata]}"; fi
}
show_type(){
echo -ne "\r${stype[title]}\n"
echo -ne "\r$Font_Cyan${stype[db]}$Font_I   IPinfo    ipregistry    ipapi     AbuseIPDB  IP2LOCATION $Font_Suffix\n"
echo -ne "\r$Font_Cyan${stype[usetype]}$Font_Suffix${ipinfo[susetype]}${ipregistry[susetype]}${ipapi[susetype]}${abuseipdb[susetype]}${ip2location[susetype]}\n"
echo -ne "\r$Font_Cyan${stype[comtype]}$Font_Suffix${ipinfo[scomtype]}${ipregistry[susetype]}${ipapi[susetype]}\n"
}
show_type_lite(){
echo -ne "\r${stype[title]}\n"
echo -ne "\r$Font_Cyan${stype[db]}$Font_I   IPinfo      ipapi    IP2LOCATION $Font_Suffix\n"
echo -ne "\r$Font_Cyan${stype[usetype]}$Font_Suffix${ipinfo[susetype]}${ipapi[susetype]}${ip2location[susetype]}\n"
echo -ne "\r$Font_Cyan${stype[comtype]}$Font_Suffix${ipinfo[scomtype]}${ipapi[susetype]}\n"
}
sscore_text(){
local text="$1"; local p2=$2; local p3=$3; local p4=$4; local p5=$5; local p6=$6; local tmplen; if ((p2>=p4));then tmplen=$((49+15*(p2-p4)/(p5-p4)-p6)); elif ((p2>=p3));then tmplen=$((33+16*(p2-p3)/(p4-p3)-p6)); elif ((p2>=0));then tmplen=$((17+16*p2/p3-p6)); else tmplen=0; fi; local tmp=$(printf '%*s' $tmplen ''); local total_length=${#tmp}; local text_length=${#text}; local tmp1="${tmp:1:total_length-text_length}$text|"; sscore[text1]="${tmp1:1:16-p6}"; sscore[text2]="${tmp1:17-p6:16}"; sscore[text3]="${tmp1:33-p6:16}"; sscore[text4]="${tmp1:49-p6}"
}
show_score(){
echo -ne "\r${sscore[title]}\n"; echo -ne "\r${sscore[range]}\n"
if [[ -n ${scamalytics[score]} ]];then sscore_text "${scamalytics[score]}" ${scamalytics[score]} 25 50 100 13; echo -ne "\r${Font_Cyan}SCAMALYTICS${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${scamalytics[risk]}\n"; fi
if [[ -n ${ipapi[score]} ]];then local tmp_score=$(echo "${ipapi[scorenum]} * 10000 / 1"|bc); sscore_text "${ipapi[score]}" $tmp_score 85 300 10000 7; echo -ne "\r${Font_Cyan}ipapi${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${ipapi[risk]}\n"; fi
if [[ $mode_lite -eq 0 ]];then sscore_text "${abuseipdb[score]}" ${abuseipdb[score]} 25 25 100 11; [[ -n ${abuseipdb[score]} ]]&&echo -ne "\r${Font_Cyan}AbuseIPDB${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${abuseipdb[risk]}\n"; if [ -n "${ipqs[score]}" ]&&[ "${ipqs[score]}" != "null" ];then sscore_text "${ipqs[score]}" ${ipqs[score]} 75 85 100 6; echo -ne "\r${Font_Cyan}IPQS${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${ipqs[risk]}\n"; fi; fi
if [ -n "${cloudflare[score]}" ]&&[ "${cloudflare[score]}" != "null" ];then sscore_text "${cloudflare[score]}" ${cloudflare[score]} 75 85 100 12; echo -ne "\r${Font_Cyan}Cloudflare${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${cloudflare[risk]}\n"; fi
sscore_text " " ${dbip[score]} 33 66 100 7; [[ -n ${dbip[risk]} ]]&&echo -ne "\r${Font_Cyan}DB-IP${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${dbip[risk]}\n"
}
format_factor(){
local tmp_txt="  "; if [[ $1 == "true" ]];then tmp_txt+="${sfactor[yes]}"; elif [[ $1 == "false" ]];then tmp_txt+="${sfactor[no]}"; elif [ ${#1} -eq 2 ];then tmp_txt+="$Font_Green[$1]$Font_Suffix"; else tmp_txt+="${sfactor[na]}"; fi; tmp_txt+="    "
if [[ $2 == "true" ]];then tmp_txt+="${sfactor[yes]}"; elif [[ $2 == "false" ]];then tmp_txt+="${sfactor[no]}"; elif [ ${#2} -eq 2 ];then tmp_txt+="$Font_Green[$2]$Font_Suffix"; else tmp_txt+="${sfactor[na]}"; fi; tmp_txt+="    "
if [[ $3 == "true" ]];then tmp_txt+="${sfactor[yes]}"; elif [[ $3 == "false" ]];then tmp_txt+="${sfactor[no]}"; elif [ ${#3} -eq 2 ];then tmp_txt+="$Font_Green[$3]$Font_Suffix"; else tmp_txt+="${sfactor[na]}"; fi; tmp_txt+="    "
if [[ $4 == "true" ]];then tmp_txt+="${sfactor[yes]}"; elif [[ $4 == "false" ]];then tmp_txt+="${sfactor[no]}"; elif [ ${#4} -eq 2 ];then tmp_txt+="$Font_Green[$4]$Font_Suffix"; else tmp_txt+="${sfactor[na]}"; fi; tmp_txt+="    "
if [[ $5 == "true" ]];then tmp_txt+="${sfactor[yes]}"; elif [[ $5 == "false" ]];then tmp_txt+="${sfactor[no]}"; elif [ ${#5} -eq 2 ];then tmp_txt+="$Font_Green[$5]$Font_Suffix"; else tmp_txt+="${sfactor[na]}"; fi
if [[ $mode_lite -eq 0 ]];then tmp_txt+="    "; if [[ $6 == "true" ]];then tmp_txt+="${sfactor[yes]}"; elif [[ $6 == "false" ]];then tmp_txt+="${sfactor[no]}"; elif [ ${#6} -eq 2 ];then tmp_txt+="$Font_Green[$6]$Font_Suffix"; else tmp_txt+="${sfactor[na]}"; fi; tmp_txt+="    "; if [[ $7 == "true" ]];then tmp_txt+="${sfactor[yes]}"; elif [[ $7 == "false" ]];then tmp_txt+="${sfactor[no]}"; elif [ ${#7} -eq 2 ];then tmp_txt+="$Font_Green[$7]$Font_Suffix"; else tmp_txt+="${sfactor[na]}"; fi; tmp_txt+="    "; if [[ $8 == "true" ]];then tmp_txt+="${sfactor[yes]}"; elif [[ $8 == "false" ]];then tmp_txt+="${sfactor[no]}"; elif [ ${#8} -eq 2 ];then tmp_txt+="$Font_Green[$8]$Font_Suffix"; else tmp_txt+="${sfactor[na]}"; fi; fi; echo "$tmp_txt"
}
show_factor(){
echo -ne "\r${sfactor[title]}\n"; echo -ne "\r$Font_Cyan${sfactor[factor]}${Font_I}IP2LOCATION ipapi ipregistry IPQS SCAMALYTICS ipdata IPinfo IPWHOIS$Font_Suffix\n"
local tmp_factor=$(format_factor "${ip2location[countrycode]}" "${ipapi[countrycode]}" "${ipregistry[countrycode]}" "${ipqs[countrycode]}" "${scamalytics[countrycode]}" "${ipdata[countrycode]}" "${ipinfo[countrycode]}" "${ipwhois[countrycode]}"); echo -ne "\r$Font_Cyan${sfactor[countrycode]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[proxy]}" "${ipapi[proxy]}" "${ipregistry[proxy]}" "${ipqs[proxy]}" "${scamalytics[proxy]}" "${ipdata[proxy]}" "${ipinfo[proxy]}" "${ipwhois[proxy]}"); echo -ne "\r$Font_Cyan${sfactor[proxy]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[tor]}" "${ipapi[tor]}" "${ipregistry[tor]}" "${ipqs[tor]}" "${scamalytics[tor]}" "${ipdata[tor]}" "${ipinfo[tor]}" "${ipwhois[tor]}"); echo -ne "\r$Font_Cyan${sfactor[tor]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[vpn]}" "${ipapi[vpn]}" "${ipregistry[vpn]}" "${ipqs[vpn]}" "${scamalytics[vpn]}" "${ipdata[vpn]}" "${ipinfo[vpn]}" "${ipwhois[vpn]}"); echo -ne "\r$Font_Cyan${sfactor[vpn]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[server]}" "${ipapi[server]}" "${ipregistry[server]}" "${ipqs[server]}" "${scamalytics[server]}" "${ipdata[server]}" "${ipinfo[server]}" "${ipwhois[server]}"); echo -ne "\r$Font_Cyan${sfactor[server]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[abuser]}" "${ipapi[abuser]}" "${ipregistry[abuser]}" "${ipqs[abuser]}" "${scamalytics[abuser]}" "${ipdata[abuser]}" "${ipinfo[abuser]}" "${ipwhois[abuser]}"); echo -ne "\r$Font_Cyan${sfactor[abuser]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[robot]}" "${ipapi[robot]}" "${ipregistry[robot]}" "${ipqs[robot]}" "${scamalytics[robot]}" "${ipdata[robot]}" "${ipinfo[robot]}" "${ipwhois[robot]}"); echo -ne "\r$Font_Cyan${sfactor[robot]}$Font_Suffix$tmp_factor\n"
}
show_factor_lite(){
echo -ne "\r${sfactor[title]}\n"; echo -ne "\r$Font_Cyan${sfactor[factor]}${Font_I}IP2LOCATION ipapi SCAMALYTICS IPinfo IPWHOIS$Font_Suffix\n"
local tmp_factor=$(format_factor "${ip2location[countrycode]}" "${ipapi[countrycode]}" "${scamalytics[countrycode]}" "${ipinfo[countrycode]}" "${ipwhois[countrycode]}"); echo -ne "\r$Font_Cyan${sfactor[countrycode]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[proxy]}" "${ipapi[proxy]}" "${scamalytics[proxy]}" "${ipinfo[proxy]}" "${ipwhois[proxy]}"); echo -ne "\r$Font_Cyan${sfactor[proxy]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[tor]}" "${ipapi[tor]}" "${scamalytics[tor]}" "${ipinfo[tor]}" "${ipwhois[tor]}"); echo -ne "\r$Font_Cyan${sfactor[tor]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[vpn]}" "${ipapi[vpn]}" "${scamalytics[vpn]}" "${ipinfo[vpn]}" "${ipwhois[vpn]}"); echo -ne "\r$Font_Cyan${sfactor[vpn]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[server]}" "${ipapi[server]}" "${scamalytics[server]}" "${ipinfo[server]}" "${ipwhois[server]}"); echo -ne "\r$Font_Cyan${sfactor[server]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[abuser]}" "${ipapi[abuser]}" "${scamalytics[abuser]}" "${ipinfo[abuser]}" "${ipwhois[abuser]}"); echo -ne "\r$Font_Cyan${sfactor[abuser]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[robot]}" "${ipapi[robot]}" "${scamalytics[robot]}" "${ipinfo[robot]}" "${ipwhois[robot]}"); echo -ne "\r$Font_Cyan${sfactor[robot]}$Font_Suffix$tmp_factor\n"
}
show_media(){
echo -ne "\r${smedia[title]}\n"
echo -ne "\r$Font_Cyan${smedia[meida]}$Font_I TikTok   Disney+  Netflix Youtube  AmazonPV  Spotify  ChatGPT $Font_Suffix\n"
echo -ne "\r$Font_Cyan${smedia[status]}${tiktok[ustatus]}${disney[ustatus]}${netflix[ustatus]}${youtube[ustatus]}${amazon[ustatus]}${spotify[ustatus]}${chatgpt[ustatus]}$Font_Suffix\n"
echo -ne "\r$Font_Cyan${smedia[region]}$Font_Green${tiktok[uregion]}${disney[uregion]}${netflix[uregion]}${youtube[uregion]}${amazon[uregion]}${spotify[uregion]}${chatgpt[uregion]}$Font_Suffix\n"
echo -ne "\r$Font_Cyan${smedia[type]}${tiktok[utype]}${disney[utype]}${netflix[utype]}${youtube[utype]}${amazon[utype]}${spotify[utype]}${chatgpt[utype]}$Font_Suffix\n"
}
read_ref(){
Media_Cookie=$(curl $CurlARG -sL --retry 3 --max-time 10 "${rawgithub}main/ref/cookies.txt")
IATA_Database="${rawgithub}main/ref/iata-icao.csv"
}

# --- 脚本主执行流程 ---
generate_random_user_agent
adapt_locale
check_connectivity
read_ref
set_language

clear

echo "正在获取公网IP地址..."
get_ipv4
get_ipv6

if [[ -n "$IPV4" ]]; then
    echo "检测到 IPv4 地址: $IPV4"
    check_IP "$IPV4" 4
else
    echo "未能检测到有效的公网 IPv4 地址。"
fi

if [[ -n "$IPV6" ]]; then
    echo "检测到 IPv6 地址: $IPV6"
    check_IP "$IPV6" 6
else
    echo "未能检测到有效的公网 IPv6 地址。"
fi
