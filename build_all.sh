#!/bin/bash
# Usage info
show_help() {
cat << EOL

Usage: . build.sh [-h -n -r -c -ncc -d -j #]
Compile Spirit with options to not repo sync, to make clean (or else make installclean),
to automatically upload the build, to not use ccache or to use a custom number of jobs.

Default behavior is to sync and make installclean.

    -h   | --help           display this help and exit
    -n   | --nosync         do not sync
    -r   | --release        move the build after compilation
    -c   | --clean          make clean instead of installclean
    -ncc | --no_ccache          build without ccache
    -d   | --debug          show some debug info
    -j #                    set a custom number of jobs to build

EOL
}

# Create necessary dir
mkdir -p $HOME/ccache/spirit
mkdir -p $HOME/spirit_output


# Configurable parameters
ccache_dir=$HOME/ccache/spirit
ccache_log=$HOME/ccache/spirit/ccache.log
jobs_sync=16
jobs_build=16
rom=SpiritRom
rom_version=v1.7
SPIRIT_VERSION_MAJOR=4.4
SPIRIT_VERSION_MINOR=4
make_command=bacon

# Reset all variables that might be set
nosync=0
noccache=0
release=0
clean=0
help=0
debug=0
zipname=""

while :
do
    case  $1 in
        -h | --help)
             show_help
             help=1
             break
            ;;
        -n | --nosync)
            nosync=1
            shift
            ;;
        -ncc | --no_ccache)
            noccache=1
            shift
            ;;
        -r | --release)
            release=1
            shift
            ;;
        -j)
                        shift
            jobs_build=$1
            shift
            ;;
        -c | --clean)
            clean=1
            shift
            ;;
        -d | --debug)
            debug=1
            shift
            ;;
        --device)
                        shift
            device_codename=$1
            shift
            ;;
        --makecommand)
                        shift
            make_command=$1
            shift
            ;;
        --rom)
                        shift
            rom=$1
            shift
            ;;
        --romversion)
                        shift
            rom_version=$1
            shift
            ;;
        --) # End of all options
            shift
            break
            ;;
        *)  # no more options. Stop while loop
            break
            ;;
    esac
done

if [[ $help = 0 ]]; then                # skip the build if help is set

# Initial build from cycle
device_codename="tilapia maguro manta"      # list of one or more devices separated by space
for dev in $device_codename
do


if [[ $noccache = 0 ]]; then            # use ccache by default
echo ''
echo '##########'
echo 'setting up ccache'
echo '##########'
echo ''
export USE_CCACHE=1
export CCACHE_DIR=$ccache_dir
export CCACHE_LOGFILE=$ccache_log
fi

echo ''
echo '##########'
echo 'syncing up'
echo '##########'
echo ''
if [[ $nosync = 1 ]]; then
        echo 'skipping sync'
else
        repo sync -j$jobs_sync -d
fi

if [[ $clean = 1 ]]; then
        echo ''
        echo '##########'
        echo 'make clean'
        echo '##########'
        echo ''
        make clean
fi

if [[ $clean = 0 ]]; then               # make installclean only if "make clean" wasn't issued
        echo ''
        echo '##########'
        echo 'make installclean'
        echo '##########'
        echo ''
        make installclean
fi


echo ''
echo '##########'
echo 'setup environment'
echo '##########'
echo ''
. build/envsetup.sh

echo ''
echo '##########'
echo 'lunch'
echo '##########'
echo ''
lunch spirit_$dev-userdebug

echo ''
echo '##########'
echo 'build ROM'
echo '##########'
echo ''

if [[ $debug = 1 ]]; then
        echo "Number of jobs: $jobs_build"
        echo ''
fi

time make $make_command -j$jobs_build   # build with the desired -j value

# resetting ccache
export USE_CCACHE=0

zipname=$(ls out/target/product/$dev/$rom-$SPIRIT_VERSION_MAJOR.$SPIRIT_VERSION_MINOR-$rom_version-*.zip | sed "s/out\/target\/product\/${dev}\///" )
if [[ $debug = 1 ]]; then
        echo '##########'
        echo 'zipname'
        echo '##########'
        echo ''
        echo $zipname
fi

if [[ $release = 1 ]]; then             # upload the compiled build
        echo ''
        echo '##########'
        echo 'copy build on spirit target dir'
        echo '##########'
        cp ./out/target/product/$dev/$zipname.md5sum $HOME/spirit_output/$zipname.md5sum
        cp ./out/target/product/$dev/$zipname $HOME/spirit_output/$zipname
        echo ''
fi
rm -rf .repo/local_manifests/roomservice.xml
done
fi
