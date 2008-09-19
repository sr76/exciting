use lib "./perl/lib/";
use XML::Simple;
use XML::Writer;
use IO::File;
use List::Util qw[min max];
use Data::Dumper;

my @allreports=collectreports();
make_summary (@allreports);



sub collectreports{
my $dir ,$file;
@reports=();
    opendir TESTROOT , "./";
   my @thefiles= readdir(TESTROOT);
    closedir(TESTROOT);
    
    foreach $dir (@thefiles)
    {
	if($dir=~m/test.*/)
	{
	    
	    opendir TESTDIR ,$dir;
	   my @thefiles2= readdir(TESTDIR);
	    closedir(TESTDIR);
	    foreach $file (@thefiles2)
	    {
		if($file=~m/.*\.xml/)
		{
		    push (@reports, readreport($dir . "/" . $file));
		}
	    }
	}
    }
    return @reports;
}



sub make_summary{
%merged=();
    $reports=@_[0];
    foreach $report (@reports)
    {
		$tests=$report->{test};
		while ( ($k,$v) = each(%$tests) ) 
		{
	    	$merged{$k} = $v;
	    	if($v->{status} eq "failed")
	    		{
	    			$failedtests{$k}=$v;
	    		} 
	    		elsif($v->{status} eq "passed")
	    		{
	    			$passedtests{$k}=$v;
	    		}
	    		else
	    		{
	    			$unspecifiedtests{$k}=$v;
	    		}
	    	
		}
	
    }
   #	print Dumper %merged;
   	$xml = new XML::Simple(NoAttr=>1, RootName=>'report',XMLDecl=>"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<?xml-stylesheet href=\"./report.xsl\" type=\"text/xsl\"?>");
    $data{test}=\%merged;
    unless (open (ALL,">./report/all.xml")){
  		die "Sorry, I couldn't create all.xml: $!";
    };
    print ALL $xml->XMLout(\%data);
    close ALL;
    
    unless (open (FAILED ,">./report/failed.xml")){
  		die "Sorry, I couldn't create failed.xml: $!";
    };
    $data{test}=\%failedtests;
    print FAILED $xml->XMLout(\%data);
    close FAILED;
    
    unless (open (PASSED ,">./report/passed.xml")){
  		die "Sorry, I couldn't create passed.xml: $!";
    };
    $data{test}=\%passedtests;
    print PASSED $xml->XMLout(\%data);
    close PASSED;
    
    unless (open (UNSPEC ,">./report/unspecified.xml")){
  		die "Sorry, I couldn't create unsecified.xml: $!";
    };
    $data{test}=\%unspecifiedtests;
    print UNSPEC $xml->XMLout(\%data);
    close UNSPEC;
    
     
    
    $npassed=keys %passedtests;
    $nfailed=keys %failedtests;
    $nall=keys %merged;
    $nunspec=keys %unspecifiedtests;
    $ppassed=$npassed/$nall*100;
    $punspec=$nunsped/$nall*100;
    $pfailed=$nfailed/$nall*100;
    
    my $output = new IO::File(">report/stats.xml");
  	my $writer = new XML::Writer(OUTPUT => $output,DATA_MODE => 'true', DATA_INDENT => 2);
  	$writer->xmlDecl( 'UTF-8' );
  	$writer->startTag("statistics");
 	$writer->emptyTag("value","name"=>"passed",count=>$npassed,percent=>$npassed/$nall*100.0);
  	$writer->emptyTag("value","name"=>"failed",count=>$nfailed,percent=>$nfailed/$nall*100.0);
   	$writer->emptyTag("value","name"=>"all",count=>$nall);
    $writer->emptyTag("value","name"=>"unspecified",count=>$nunspec,percent=>$nunspec/$nall*100.0);
    $writer->endTag("statistics");
    $output=$writer-> getOutput();
  	$output->close();
  	open(HTML,">report/index.html");
  	print HTML "<html><body><h1>Test Result</h1><p>Test suite run from";
  	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  	$mon=$mon+1;
  	print HTML " $mday.$mon $hour:$min :</p><p>  ";
  	 
  	print HTML "<img src=\"";
  	print HTML "http://chart.apis.google.com/chart?cht=bhs";
  	print HTML "&chd=t:$ppassed|$punspec|$pfailed&";
  	print HTML "chs=500x80&";
 
  	print HTML "chdl=passed|unspecified|failed&chdlp=t&";
  	print HTML "chl=passed:$npassed|unspecified:$nunspec|failed:$nfailed&";
  	print HTML "chco=006600,f0f000,cc0033";
  	print HTML "\" >";
  	print HTML "</p>";
  	print HTML "<p><a href=passed.xml>passed</a> ";
  	print HTML "<a href=unspecified.xml>unspecified</a> ";
  	print HTML "<a href=failed.xml>failed</a> </p>";
  		print HTML "</body></html>";
	close (HTML);
}


sub readreport($file)
{
    $xml = new XML::Simple(NoAttr=>1, RootName=>'report');
    
# read XML file
#print @_[0];
    $data = $xml->XMLin(@_[0]);
    
    return $data;
}



