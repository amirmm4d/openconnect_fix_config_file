#!/bin/bash

# بخش 0: تعریف رنگ‌ها و نوار پیشرفت

# تعریف رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # بدون رنگ

# تابع برای نمایش پیام‌های رنگی
colored_echo() {
   color="$1"
   message="$2"
   echo -e "${color}${message}${NC}"
}

# تابع برای نمایش پیام‌های خطا
error_echo() {
   colored_echo "$RED" "$1"
}

# تابع برای نمایش پیام‌های موفقیت
success_echo() {
   colored_echo "$GREEN" "$1"
}

# تابع برای نمایش پیام‌های درخواست ورودی
input_echo() {
   colored_echo "$BLUE" "$1"
}

# تابع برای نمایش پیام‌های درخواست فایل
file_input_echo() {
   colored_echo "$PURPLE" "$1"
}

# تابع برای نمایش نوار پیشرفت
progress_bar() {
   percentage=$1
   width=50
   filled=$(($percentage * $width / 100))
   unfilled=$(($width - $filled))
   bar=$(printf "%${filled}s" | tr ' ' '#')
   space=$(printf "%${unfilled}s")
   printf "\r[${YELLOW}${bar}${NC}${space}] ${percentage}%%"
}

# بخش 1: بررسی ورودی‌ها و فایل کانفیگ
check_input() {
   if [ -z "$1" ]; then
      error_echo "لطفاً نام فایل کانفیگ را به عنوان پارامتر وارد کنید."
      exit 1
   fi

   config_file="$1"

   # چک کردن وجود فایل
   if [ ! -f "$config_file" ]; then
      error_echo "فایل $config_file وجود ندارد."
      exit 1
   fi

   success_echo "فایل $config_file پیدا شد."
}

# بخش 2: تعریف فانکشن‌ها برای پردازش خطوط مختلف
process_line() {
   line="$1"
   if [[ $line == \#* ]]; then
      colored_echo "$YELLOW" "Commented line: $line"
   elif [[ $line == \!#* ]]; then
      colored_echo "$YELLOW" "Uncommented line: ${line:2}"
   elif [[ $line == \$* ]]; then
      var_name=$(echo "$line" | cut -d' ' -f1)
      var_value=$(echo "$line" | cut -d'=' -f2-)
      if [ -z "$var_value" ]; then
         input_echo "Enter value for $var_name: "
         read input
         while [ -z "$input" ]; do
            input_echo "Value for $var_name cannot be empty. Please enter: "
            read input
         done
         line="$var_name = $input"
      else
         input_echo "Enter value for $var_name (default: $var_value): "
         read input
         line="$var_name = ${input:-$var_value}"
      fi
      success_echo "Updated line: $line"
   else
      colored_echo "$YELLOW" "No special handling needed for: $line"
   fi
   echo "$line"
}

# تابع برای نمایش راهنما
show_help() {
   echo "Usage: $(basename "$0") [-h] [-f config_file] [-x script_file] [-s variable_name] [-S new_value] [-a] [-c backup_file]"
   echo "Options:"
   echo "  -h, --help             Show this help message and exit"
   echo "  -f <config_file>       Specify the configuration file to process"
   echo "  -x <script_file>       Execute the script after applying changes"
   echo "  -s <variable_name>     Search for a variable name in the configuration file"
   echo "  -S <new_value>         Replace the value of a variable in the configuration file"
   echo "  -a                     List all variables with their values in the configuration file"
   echo "  -c <backup_file>       Create a backup of the configuration file with a custom name"
   echo
}

# بخش 3: گرفتن ورودی‌های کاربر
process_file() {
   total_lines=$(wc -l <"$config_file")
   current_line=0
   while IFS= read -r line; do
      processed_line=$(process_line "$line")
      echo "$processed_line"
      current_line=$((current_line + 1))
      progress_percentage=$((current_line * 100 / total_lines))
      progress_bar $progress_percentage
   done <"$config_file"
   echo
}

# بخش 4: اعمال تغییرات در فایل کانفیگ
apply_changes() {
   temp_file=$(mktemp)
   process_file >"$temp_file"
   mv "$temp_file" "$config_file"
   success_echo "Changes have been applied to $config_file."
}

# بخش 5: اضافه کردن کامندهای ورودی و بررسی‌ها

file_path=""
execute_script=""
copy_file=""
search_var=""
search_replace=""

# بررسی کامند‌های ورودی
while getopts ":h:f:x:s:S:a:c:" opt; do
   case $opt in
   h | \?)
      show_help
      exit 0
      ;;
   f)
      file_path="$OPTARG"
      ;;
   x)
      execute_script="$OPTARG"
      ;;
   s)
      search_var="$OPTARG"
      ;;
   S)
      search_replace="$OPTARG"
      ;;
   a)
      list_all=true
      ;;
   c)
      copy_file="$OPTARG"
      ;;
   :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
   esac
done

if [ -z "$file_path" ] && [ ! -z "$execute_script" ]; then
   file_input_echo "Please enter the file path: "
   read file_path
fi

if [ -z "$file_path" ]; then
   error_echo "File path is required with -f option."
   exit 1
fi

# اعمال تغییرات در فایل کانفیگ
check_input "$file_path"

# اعمال تغییرات در فایل کانفیگ
if [ ! -z "$copy_file" ]; then
   cp "$config_file" "$copy_file"
   success_echo "Backup created at $copy_file"
fi

apply_changes

# اجرای اسکریپت پس از اعمال تغییرات
if [ ! -z "$execute_script" ]; then
   if [ $? -eq 0 ]; then
      bash "$execute_script"
   else
      error_echo "There were errors. The script $execute_script was not executed."
   fi
fi
