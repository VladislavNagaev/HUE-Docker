#!/bin/bash

echo "Hue-node configuration started ..."

function configure_ini() {

    local path=$1
    local envPrefix=$2

    echo -e "${cyan_on}Configuring $path${reset_font}"

    for c in `printenv | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- -envPrefix=$envPrefix`; do 

        local space='\x20';

        local sections_dirty=`echo ${c} | perl -pe 's/(\w*____)(\w*)/${1}/g;'`;
        local sections_preprocessed=`echo ${sections_dirty} | perl -pe 's/____([0-9])/"["x${1}/ge; s/([0-9])____/"]"x${1}/ge;'`;
        local sections_readable=`echo ${sections_preprocessed} | perl -pe 's/___/-/g; s/__/@/g; s/_/./g; s/@/_/g;'`;
        local sections_delimeter=`echo ${sections_readable} | perl -pe 's/\]\[/\],\[/g;'`;
        readarray -td ',' sections_array <<<"$sections_delimeter,"; unset 'sections_array[-1]';
        # declare -p sections_array;

        local sections_level_l=`echo ${sections_dirty} | perl -pe 's/____([0-9])(?:(?!____([0-9])|([0-9])____).)*([0-9])____/${1},/g;'`;
        readarray -td ',' sections_level_array_l <<<"$sections_level_l"; unset 'sections_level_array_l[-1]';
        local sections_level_r=`echo ${sections_dirty} | perl -pe 's/____([0-9])(?:(?!____([0-9])|([0-9])____).)*([0-9])____/${4},/g;'`;
        readarray -td ',' sections_level_array_r <<<"$sections_level_l"; unset 'sections_level_array_r[-1]';
        if ! [[ "${sections_level_array_l[@]}" == "${sections_level_array_r[@]}" ]] ; then
            echo -e "${yellow}Variable <"$c"> is not compatible!${reset_font}" ;
            continue;
        fi;
        local sections_level_array=("${sections_level_array_l[@]}")

        local name_dirty=`echo ${c} | perl -pe 's/(\w*____)(\w*)/${2}/g;'`;
        local name_readable=`echo ${name_dirty} | perl -pe 's/___/-/g; s/__/@/g; s/_/./g; s/@/_/g;'`;
        local name=$name_readable;

        local var="${envPrefix}_${c}";
        local value_dirty=${!var};
        local value_readable=$value_dirty;
        local value=$(echo $value_dirty | sed 's/\//\\\//g; s/\@/\\@/g;');

        local p_start='\n'$space'*'
        local ps_comm='\n#*'$space'*';
        local pe_comm='\n#+'$space'*';
        local p_center='[^\s\[\]]+';
        local p_left='';
        local p_right='[^\]]';

        local pattern='';
        local pattern_short='';

        local length=${#sections_array[@]};

        for (( j=0; j<${length}; j++ )); do

            section_readable=${sections_array[$j]};
            section=$(echo ${section_readable} | perl -pe 's/\[/\\[/g; s/\]/\\]/g;');
            sections_level=${sections_level_array[$j]};

            local except='';

            for (( e=1; e<=$(( $sections_level-1 )); e++ )); do

                local except_i=`perl -E "print '"$p_start"','"$p_left"','\['x"$e",'"$p_center"','\]'x"$e",'"$p_right"';"`;

                if [[ -n ${except} ]]; then
                    except+='|'$except_i;
                else
                    except=$except_i;
                fi;

            done;

            local except_last=`perl -E "print '"$ps_comm$p_left"','\['x"$sections_level",'"$p_center"','\]'x"$sections_level",'"$p_right"';"`;

            if [[ -n ${except} ]]; then
                local except_full=$except'|'$except_last;
            else
                local except_full=$except_last;
            fi;

            local p_last='(?:(?!'$except_full').)*';

            # если j >= 1
            if [ $j -ge 1 ]; then
                pattern_short=$pattern'(?:(?!'$except').)*';
                pattern+='(?:(?!'$except').)*'$section;
            else
                pattern=$section;
            fi;

            # Если секция найдена
            if [[ -n "$(cat $path | perl -n0e '/'$pattern_short$ps_comm$section'\s*/s && print $&')" ]]; then

                # Если секция неактивна
                if [[ -n "$(cat $path | perl -n0e '/'$pattern_short$pe_comm$section$space'*/s && print $&')" ]]; then
                    
                    local str_sections=$(for (( i=0; i<=$j; i++ )); do printf "${sections_array[$i]}"$space; done)
                    echo -e "${purple} - Activation section $str_sections${reset_font}";

                    perl -i -p0e 's/('$pattern_short')'$pe_comm'('$section$space'*)/${1}\n${2}/sg' $path;

                fi;
            
            # Иначе создать секцию
            else

                local str_sections=$(for (( i=0; i<=$j; i++ )); do printf "${sections_array[$i]}"$space; done);
                echo -e "${purple} - Adding section $str_sections${reset_font}";

                # если j >= 1
                if [ $j -ge 1 ]; then
                    perl -i -p0e 's/('$pattern_short')('$space'*)/${1}${2}\n'$section'/sg' $path;
                else
                    echo -e "\n$section" | tee -a ${path} > /dev/null;
                fi;

            fi;

            # Если j является последним элементом
            if [ $(( $j+1 )) -eq $length ]; then

                if [[ -n ${name} ]]; then

                    echo -e "${green} - Setting $name_readable=$value_readable in section ${sections_array[*]}${reset_font}";

                    # Если шаблон найден
                    if [[ -n $(cat $path | perl -n0e '/'$pattern$p_last$ps_comm$name$space'*=[^\n]*/s && print $&') ]]; then
                        # Изменение значения в последнем уровне section
                        perl -i -p0e 's/('$pattern$p_last')'$ps_comm'('$name')'$space'*=[^\n]*/${1}\n${2}='"$value"'/sg' $path;
                    else
                        # Иначе вставить новую строку после последнего уровня section
                        perl -i -p0e 's/('$pattern')('$space'*)/${1}${2}\n'$name'='"$value"'/sg' $path;
                    fi;

                fi;

            fi;

        done;

    done;
}


if ! [ -z ${HUE_CONF_DIR+x} ]; then
    
    configure_ini ${HUE_CONF_DIR}/hue.ini CONF_HUE;

fi;

echo "Hue-node configuration completed!";
