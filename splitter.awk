#! /usr/bin/awk -f 
BEGIN {
	header = 1
	yaml_parts = 0;
	part_count = 0
	code = 0
}
{
if( $0 == "---")
	yaml_parts++;
else if( $0 ~ / highlight/)
	code = 1;
if( header )
	filename = "md000.header";
else if( code )
	filename = sprintf("md%.2d.hcode", part_count);
else
	filename = sprintf("md%.2d.content", part_count);
print >filename
if( yaml_parts == 2 )
	header = 0;
if ( $0 ~ / endhighlight/)
{
        code = 0;
        part_count++;
}
}
END {
}	
