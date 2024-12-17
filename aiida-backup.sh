#!/bin/bash

# CLI OPTIONS (IGNORE!) #################################################################

show_help() {
    echo
    echo "Usage: ./aiida-backup.sh [-h] [-e env-type] [-c conda-env] [-v venv-path] [-p projects-path] [-n project-name]"
    echo
    echo "Options:"
    echo "  -h                Show this help message"
    echo "  -e env-type       The type of environment to activate (conda, venv, aiida-project)"
    echo "  -c conda-env      The name of the Conda environment to activate"
    echo "  -v venv-path      The path to the virtual environment to activate"
    echo "  -n project        The name of the AiiDA project"
    echo "  -p profiles       The names of AiiDA profiles to backup (optional) - if not specified, all profiles will be backed up"
    echo
}

if [ "$#" -eq 0 ] || [ "${1:0:1}" != "-" ]; then
    show_help
    exit 0
fi

while getopts "he:c:v:a:n:p:" opt; do
    case "${opt}" in
    h) show_help && exit 0 ;;
    e) env=$OPTARG ;;
    c) conda_env=$OPTARG ;;
    v) venv_path=$OPTARG ;;
    n) project=$OPTARG ;;
    p) profiles=$OPTARG ;;
    *) echo "Invalid argument. Run with -h for help." && exit 1 ;;
    esac
done

if [ ! "$project" ]; then
    echo "Project name not specified. Use -n <name>" && exit 1
fi

case "${env}" in
conda)
    if [ ! "$conda_env" ]; then
        echo "Conda environment not specified. Use -c <name>" && exit 1
    fi
    source $(conda info --base)/etc/profile.d/conda.sh
    conda activate "$conda_env"
    ;;
venv)
    if [ ! "$venv_path" ]; then
        echo "Virtual environment path not specified. Use -v <path>"
        exit 1
    fi
    source "$venv_path/bin/activate"
    ;;
aiida-project)
    if [ ! -f "$HOME/.aiida_project.env" ]; then
        echo ".aiida_project.env not found in user directory. Is aiida-project initialized?" && exit 1
    fi
    export "$(grep -v '^#' "$HOME/.aiida_project.env" | xargs)"
    source $aiida_venv_dir/$project/bin/activate
    ;;
*)
    echo "Python environment type not specified. Use -e <conda|venv|aiida-project>" && exit 1
    ;;
esac

# ROOT DIRECTORY FOR ALL BACKUPS ########################################################

ROOT="/home/edanb/PSI/group/aiida-backup-setup/backups/aiida"

# BACKUP UTILITY ########################################################################

backup() {
    local project=$1
    local profiles=$2
    local log_file="$ROOT/$project/backup.log"

    # Overwite log file, if exists
    echo -e "\nProfiles to backup: \"$profiles\"\n" 2>&1 | tee $log_file

    if [ ! "$profiles" ]; then
        profiles=$(verdi profile list)
        if grep -q Warning <<<"$profiles"; then
            echo "No profiles found!" | tee -a $log_file && exit 1
        else
            profiles=$(echo "$profiles" | xargs | cut -d '*' -f2)
        fi
    fi

    echo -e "\nBacking up \"$project\" project\n" 2>&1 | tee -a $log_file

    for profile in $profiles; do
        path="$ROOT/$project/$profile"
        mkdir -p "$path"
        echo -e "\nBacking up \"$profile\" profile to $path \n" 2>&1 | tee -a $log_file
        (verdi -p "$profile" storage backup "$path") 2>&1 | tee -a $log_file
    done
}

# RUN BACKUP UTILITY ####################################################################

backup "$project" "$profiles"
