#move all files from their folders and put them in a raw_data folder
#mkdir raw_data
#find . -mindepth 2 -type f -exec mv -i {} ./raw_data/ \;
#rm -r maehr*
ls ./raw_data/ -1 > file_list.txt