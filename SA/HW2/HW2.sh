#!/bin/sh
# HelpMessage when error
help_msg="hw2.sh -i INPUT -o OUTPUT [-c csv|tsv] [-j]

Available Options:

-i: Input file to be decoded
-o: Output directory
-c csv|tsv: Output files.[ct]sv
-j: Output info.json
"

# errorfiles count
error_files=0

# Parse flags with getopts
while getopts ":c:i:o:j" opt; do
    case "$opt" in
        
        i) input_file="$OPTARG";;
        o) outputDir="$OPTARG";;
        c)  c_t=$OPTARG
            if [ "$c_t" = "tsv" ]; then sep="\t"; fi
            if [ "$c_t" = "csv" ]; then sep=","; fi
            ;;
        j) json=true 
           ;;
        \?) echo "$help_msg" >&2 
            exit 1
            ;;
        :) echo "$help_msg" >&2 
            exit 1
            ;;        
    esac
done

case "$input_file" in
    *.hw2) 
        # do nothing
        ;;
    *) 
        # do something if it doesn't match
        echo "Input file format error"
        echo "$help_msg" >&2
        exit 1
        ;;
esac

mkdir -p "$outputDir"
if [ ! -d "$outputDir" ]; then
    echo "Please specify an output directory"
    echo "$help_msg" >&2
    exit 1
fi

if [ "$json" ]; then
    name=$(yq -e ".name" "$input_file" | tr -d "'\"")
    author=$(yq -e ".author" "$input_file" | tr -d "'\"")
    date=$(yq -e ".date" "$input_file")
    if [ "$(uname -s)" = "Darwin" ]; then date=$(date -s "@$date"  -Iseconds); fi
    if [ "$(uname -s)" = "FreeBSD" ]; then date=$(date -r "$date" -Iseconds); fi

    jq -n --arg name "$name" --arg author "$author" --arg date "$date" '{name: $name, author: $author, date: $date}' > "$outputDir/info.json"
fi

if [ "$c_t" ]; then
    printf "filename%ssize%smd5%ssha1\n" "$sep" "$sep" "$sep" > "$outputDir/files.$c_t"
fi

length=$(yq -e '.files | length' "$input_file")
i=0
while [ "$i" -lt "$length" ]; do
    files=$(yq -e ".files[$i]" "$input_file")
    name=$(echo "$files"| yq -e '.name' | tr -d "'\"")
    data=$(echo "$files"| yq -e .data | tr -d "'\"")
    md5=$(echo "$files"| yq -e '.hash."md5"' | tr -d "'\"")
    sha1=$(echo "$files"| yq -e '.hash."sha-1"' | tr -d "'\"")

    # create the directory if a file name contains nested directories
    mkdir -p "$outputDir"/"$(dirname "$name")"

    # Decode the data 
    echo "$data" | base64 --decode > "$outputDir"/"$name"
    # compute data size
    size=$(stat -f %z "$outputDir"/"$name" )


    # Compute the MD5 checksum of the decoded data
    computed_md5=$(md5sum "$outputDir"/"$name" | cut -d ' ' -f 1)

    # Compute the SHA-1 checksum of the decoded data
    computed_sha1=$(sha1sum "$outputDir"/"$name" | cut -d ' ' -f 1)

    # Compare the computed checksums with the provided checksums
    if [ "$computed_md5" != "$md5" ] || [ "$computed_sha1" != "$sha1" ]; then
        error_files=$(( "$error_files" + 1 ))
    fi

    if [ "$c_t" ]; then
        printf "%s%s%s%s%s%s%s\n" "$name" "$sep" "$size" "$sep" "$md5" "$sep" "$sha1" >> "$outputDir/files.$c_t"
    fi
    i=$(( "$i" + 1 ))

done

return "$error_files"