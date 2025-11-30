#!/usr/bin/env bash
# set -x         # отладка: полный лог исполняемых команд
# set -o xtrace  # отладка: полный лог исполняемых команд
  
# initialisation
TEST=0
  
# Пример инициализации переменной дефолтным значением, если ещё не была определена ранее
# , где `app` и `docker_tag` -- имена ранее определенных переменных.
# Если IMAGE_NAME была определена ранее, то будет использоваться прежнее значение, а дефолтное проигнорится
: ${IMAGE_NAME:="${app}-sshd:${docker_tag}"}
  
parseopts () {
    # двоеточие в начале подавляет вывод стандартных ошибок
    # while getopts ":d:s:g:" optname
    while getopts "hd:s:g:t" optname
        do
            case "$optname" in
                "h")
                    # print help and exit
                    # echo "Option $optname is specified";
                    echo "
Usage: $0 -d DIRECTORY -s SRC_SUFFIX -g GOAL_SUFFIX [-t]
$0 -h
  
    Скрипт обходит рекурсивно указанный в опции '-d' каталог DIRECTORY,
    заменяет в именах файлов суффикс (расширение) SRC_SUFFIX
    на GOAL_SUFFIX (указанные в опциях '-s' и '-g' соответственно).
  
    Опции:
  
        -d путь к каталогу
  
        -s суффикс, который будем заменять
  
        -g суффикс, который будем подставлять на место прежнего
  
        -t выполнить в тестовом режиме, не переименовывать файлы
  
        -h показать эту справку
  
    Примеры:
  
        $0 -d $HOME -s tmp -g temp
        $0 -d . -s txt -g sh -t
        $0 -h
  
";
                    exit 0;
                    ;;
                "d")
                    # working directory
                    # echo "Option $optname has value $OPTARG"
                    WORKDIR=$OPTARG
                    ;;
                "s")
                    # source suffix
                    # echo "Option $optname has value $OPTARG"
                    SRC=$OPTARG
                    ;;
                "g")
                    # goal suffix
                    # Echo "Option $optname has value $OPTARG"
                    GOAL=$OPTARG
                    ;;
                "t")
                    # no changes
                    echo '
[Test mode] No changes.
'
                    TEST=1
                    ;;
                "?")
                    echo "Unknown option $OPTARG"
                    exit 2
                    ;;
                ":")
                    echo "No argument value for option $OPTARG"
                    exit 3
                    ;;
                *)
                    echo "Unknown error while processing options"
                    exit 4
                    ;;
               esac
          done
     return $OPTIND
}
  
# parse options
parseopts "$@"
  
# Options validating
  
# Does directory exists?
if [ -d "$WORKDIR" ] ; then
    echo "DIRECTORY: ${WORKDIR}";
else
    echo "ERROR: directory ${WORKDIR} does not exist";
    exit 1
fi
  
# -s, -g are not empty-string
if [ -z $SRC ] ; then
    echo "ERROR: option '-s' is empty";
    exit 1
fi
if [ -z $GOAL ]; then
    echo "ERROR: option '-g' is empty";
    exit 1
fi
  
# если суффикс начинается с точки, она не нужна (уже указана в шаблонах)
# отрезаем точку из начала суффикса
SRC=$(echo $SRC | sed "s/^\.//g")
GOAL=$(echo $GOAL | sed "s/^\.//g")
  
echo "SRC_SUFFIX: ${SRC}"
echo "GOAL_SUFFIX: ${GOAL}"
  
# go ahead!
for oldname in $(find ${WORKDIR} -type f -name *.$SRC);
do
    newname=`echo $oldname | sed "s/\.${SRC}$/\.${GOAL}/g"`;
    if [ $TEST -eq 1 ] ; then
        echo $oldname --> $newname
    else
        echo "mv $oldname $newname"
        mv $oldname $newname
    fi
done
  
if [ $TEST -eq 1 ] ; then
    echo '
[TEST DONE]'
else
    echo '
[DONE]'
fi
