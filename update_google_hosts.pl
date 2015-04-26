#!/usr/bin/perl -w
# info4life project
# update_google_hosts.pl
#
# In china, use google a not easy
# This programe ,spide google hosts info from 360doc
# and update local file '/etc/hosts',then send an email 
# https://github.com/chrisfoon/info4life
#
use strict;
use Cwd;
use LWP;
use Net::SMTP;
use MIME::Lite;
use File::Copy;
#use Encode;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my $url = "http://www.360kb.com/kb/2_122.html";
my $dir = getcwd.'/tmp';
mkdir($dir) unless -e $dir;
my $tag_file = $dir."/hosts.tmp";
# get hosts update info
my $browser = LWP::UserAgent->new();
my $ua = $browser->get($url);
my $body = $ua->content;
my ($summary) = $body =~ m{<pre>(.*)</pre>}s;
die "html source format changed\n" unless $summary;
my @arr_hosts = split/\n/,$summary;
map{$_ = /^((?:(?:25[0-5]|2[0-4]\d|((1\d{2})|([1-9]?\d)))\.){3}(?:25[0-5]|2[0-4]\d|((1\d{2})|([1-9]?\d))))\s+|^#/?$_ :'#'.$_; } @arr_hosts;
my $new_hosts = join "\n",@arr_hosts;

my $ckkey = md5_hex($new_hosts);
if(-e $tag_file){
  open my $tf,"<",$tag_file;
  my $lastkey = do { local $/; <$tf>; };
  close($tf);
  chomp($lastkey);
  md5_hex($lastkey);
  exit if $lastkey eq $ckkey;
}

# Read old hosts info
my $hostfile = -e '/etc/hosts' ? '/etc/hosts'
 : -e 'C:\Windows\System32\drivers\etc\hosts' ? 'C:\Windows\System32\drivers\etc' 
 : die "Can not file hosts file\n" ;
open my $hf,"<",$hostfile or die "can not open file: $hostfile \n";
my $old_host_str = do { local $/; <$hf>; };
my $self_host = (split/'#--split--#'/,$old_host_str)[0];
close($hf);
my $tmphostfile = $dir."/hosts";
open my $whf,">",$tmphostfile or die "can not write hosts file\n";
if($self_host){
  print $whf $self_host."\n";
} else {
  print $whf $old_host_str."\n";
}
print $whf "#--split--#\n";
print $whf $new_hosts."\n";
close($whf);

# move new host file to system host dir
move($tmphostfile,$hostfile) or die $!.",Plead Use sudo or root to run\n";

# send mail config
my $mail_cont =  "<a href='$url' target='_blank'>Google Hosts Update</a>:<br/>";
my $mail_sub  =  "Google Hosts Update ";

# smtp server setting
my $smtp_server = 'smtp.126.com';
my $smtp_user = 'smtpusername';
my $smtp_pwd  = 'password';

my $mail_from = 'from@126.com';
my $mail_to   = 'to@126.com';
my $mail_file = $hostfile;

&send_mail( 
  { 'server'=>{ 
      'host'=>$smtp_server, 
      'user'=>$smtp_user,
      'pwd'=>$smtp_pwd,
    },
  'from'=>$mail_from,  
  'to'=>$mail_to,  
  'subject'=>$mail_sub,  
  'content'=>$mail_cont,  
  'file'=>$hostfile
  } 
);

# write tag file
open my $tgf,">",$tag_file;
print $tgf $ckkey;
close($tgf);

# function of sending mail
sub send_mail(){
  my $info = shift;
  my $host = $info->{server}{host};
  my $user = $info->{server}{user};
  my $pwd = $info->{server}{pwd};

  my $from = $info->{from};
  my $to = $info->{to};
  my $subject = $info->{subject};
  my $content = $info->{content};

  my $file = '';
  my $file_name = '';
  if (exists $info->{file}){
    $file = $info->{file};
    $file_name = (split/\//,$file)[-1];
  }

  my $smtp = Net::SMTP->new($host,Debug=>0);
     $smtp->auth($user,$pwd);
     $smtp->mail($from);
     $smtp->to($to);

  my $msg = MIME::Lite->new(
     From => $from,
     To => $to,
     Subject => $subject,
     Type => 'multipart/mixed' 
  );
  
  $msg->attach(Type=>'text/html;charset=utf-8',Data=>$content);
  $msg->attach(Type=>'AUTO',Path=>$file, Filename=>$file_name);

  my $str = $msg->as_string() or print $!;
  $smtp->data();
  $smtp->datasend($str);
  $smtp->dataend();
  $smtp->quit;
}

