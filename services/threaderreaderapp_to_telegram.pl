#!/usr/bin/perl
use strict;
use warnings;
use 5.26.0;
no autovivification;
binmode STDOUT, ":utf8";
use utf8;
use Data::Printer;
use Data::Dumper;
use JSON;
use File::Temp;
use HTTP::Cookies;
use HTML::Tree;
use LWP::UserAgent;
use LWP::Simple;
use HTTP::Cookies qw();
use HTTP::Request::Common qw(POST OPTIONS);
use HTTP::Headers;
use Hash::Merge;
use File::Path qw(make_path);
use WWW::Telegram::BotAPI;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Project's libraries.
use config;
use time;
use json_parsing;

# Initiates Telegram API.
my $fullArchiveChecked  = 0;
my $telegramToken       = $config{'telegramToken'} // die;
my @telegramChannels    = ('1001697735147'); # Channels on which you want to broadcast. Bot must be invited as admin in these channels.
my $telegramApi         = WWW::Telegram::BotAPI->new (
    token => $telegramToken
);
my $telegramBotName     = $telegramApi->getMe->{result}{username};
my $dt                  = time::current_datetime();
say "[$dt] - Initiated Telegram Bot [$telegramBotName]";

# UA used to fetch data from threadreaderapp.
my $cookie              = HTTP::Cookies->new();
my $userAgent           = 'Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36';
my $ua                  = LWP::UserAgent->new
(
    timeout    => 30,
    cookie_jar => $cookie,
    agent      => $userAgent
);
my $urlBase             = 'https://threadreaderapp.com';
my $url                 = "$urlBase/user/Jikkyleaks";
my %threads             = ();
if (-f $threadsFile) {
	$fullArchiveChecked = 1;
	known_threads();
}

my %urlsReplacement     = ();
my $latestUts;
my $initiated = 0;

while (1) {
    my $dt    = time::current_datetime();
    STDOUT->printflush("\r[$dt] - Monitoring [$url]");
	list_recent_threads();
}

sub known_threads {
	my $json = json_parsing::json_from_file($threadsFile);
	%threads = %$json;
}

sub list_recent_threads {
	my $res = $ua->get($url);
	unless ($res->is_success)
	{
	    my $dt    = time::current_datetime();
	    say "[$dt] - Failed to get [$url]";
	    return;
	}
	my $content   = $res->decoded_content;
	unless ($content) {
	    my $dt    = time::current_datetime();
	    say "[$dt] - Failed to get [$url]";
	    return;
	}

	# Incrementing the few css lines we need to keep the page read-able.
	$content .= '<style type="text/css">.about-user{border-bottom:1px dotted #ccc;padding-bottom:20px;margin-bottom:0}.thread-card .time{font-size:13px;position:relative;width:100px;text-align:left;top:0;left:0;background:0 0;margin-left:0;white-space:nowrap;padding-bottom:20px}.thread-card{border:none;border-radius:0;position:relative;cursor:pointer;box-shadow:none;border-bottom:1px solid #ccc;padding:20px 15px 15px;margin-bottom:0}.thread-card:hover{transition:none;transform:none;box-shadow:none;background:#f2f2f2}.thread-info{font-size:14px;margin:0 0 15px}.col-md-6 .col-lg-4{-ms-flex:0 0 100%;flex:0 0 100%;max-width:100%}.entity-image img,.entity-video video,.entity-embed .youtube-player,.entity-video-gif video,.entity-embed .twitter-player blockquote{display:none}.entity-image,.entity-embed,.entity-url,.entity-multiple-2,.entity-multiple-3,.entity-multiple-4,.entity-video{display:none}.card-tweetsv2{display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden;margin-bottom:20px;font-style:normal;font-size:1rem;line-height:1.58;letter-spacing:-.003em;margin-bottom:1.25rem;word-wrap:break-word;cursor:pointer}.thread-card .read-more{font-size:14px;text-decoration:underline}.thread-card .read-more:hover{background:0 0;text-decoration:underline}.thread-card .entity-image img,.thread-card .entity-video video,.thread-card .entity-embed .youtube-player,.thread-card .entity-video-gif video,.thread-card .entity-embed .twitter-player blockquote{display:none}.thread-card .content-tweet,.search-card .content-tweet{font-size:1.1rem}.nop{color:#000}.thumb-div{height:71px;width:100px;display:inline}.thumb-div img{height:71px;width:100px;object-fit:cover;float:left;margin-right:10px;border:1px solid #999}.dot3{margin:0 2px}</style>';
	my $tree  = HTML::Tree->new();
	$tree->parse($content);

	# Fetching the listed threads URLs.
	my @divs = $tree->find('div');
	for my $div (@divs) {
		next unless $div->attr_get_i('data-link-href');
		my $href = $div->attr_get_i('data-link-href');
		next unless $href && $href =~ /\Q\/thread\/\E/;
		parse_thread($href, $div);
	}

	if ($latestUts && !$fullArchiveChecked) {
		my $formerUts       = '9999999999';
		while ($formerUts > $latestUts) {
			$formerUts = $latestUts;
			my $url    = "https://threadreaderapp.com/user/Jikkyleaks?ajax=true&before=$latestUts";
	    	say "[$dt] - Archiving Past Threads: [$url]";
			my $res    = $ua->get($url);
			unless ($res->is_success)
			{
			    my $dt    = time::current_datetime();
			    say "[$dt] - Failed to get [$url]";
			    return;
			}
			my $content   = $res->decoded_content;
			unless ($content) {
			    my $dt    = time::current_datetime();
			    say "[$dt] - Failed to get [$url]";
			    return;
			}

			# Incrementing the few css lines we need to keep the page read-able.
			my $tree  = HTML::Tree->new();
			$tree->parse($content);
			my @divs = $tree->find('div');
			for my $div (@divs) {
				next unless $div->attr_get_i('data-link-href');
				my $href = $div->attr_get_i('data-link-href');
				next unless $href && $href =~ /\Q\/thread\/\E/;
				parse_thread($href, $div);
			}
		}
		$fullArchiveChecked = 1;	
	}

	# Dumping current threads archive.
	open my $out, '>:utf8', $threadsFile;
	say $out encode_json\%threads;
	close $out;
}

sub parse_thread {
	my ($href, $div) = @_;
	my ($threadId)   = $href =~ /\/thread\/(.*)\.html/;
	unless (exists $threads{$threadId}->{'detected'}) {
		if ($initiated == 0) {
			$initiated = 1;
			say "";
		}
		my $dt = time::current_datetime();
		say "[$dt] - Archiving Thread: [$threadId]";
		%urlsReplacement = ();
		$threads{$threadId}->{'detected'} = 1;
		archive_thread($threadId);

		my $span       = $div->look_down(class=>"time");
		my $threadUts  = $span->attr_get_i('data-time');
		my $threadDt   = time::timestamp_to_datetime($threadUts);
		my $currentUts = time::current_timestamp();
		$latestUts     = $threadUts;

		# Reposting the thread if more recent than a day old.
		if ($threadUts + 86400 > $currentUts) {

			# If the post is recent, reposting it on Telegram channels.
			for my $telegramChannelId (@telegramChannels) {
				my $dt = time::current_datetime();
				say "[$dt] - Re-posting Thread: [$threadId] to Telegram Channel [$telegramChannelId]";
	            $telegramApi->sendMessage ({
	                chat_id => "-$telegramChannelId",
	                text    => "$urlBase/thread/$threadId.html"
	            });
	            sleep 1;
			}
		}
	}
}

sub archive_thread {
	my $threadId = shift;

	my $url = "$urlBase/thread/$threadId.html";
	my $res = $ua->get($url);
	unless ($res->is_success)
	{
	    my $dt    = time::current_datetime();
	    say "[$dt] - Failed to get [$url]";
	    return;
	}
	my $content   = $res->decoded_content;
	unless ($content) {
	    my $dt    = time::current_datetime();
	    say "[$dt] - Failed to get [$url]";
	    return;
	}
	my $tree  = HTML::Tree->new();
	$tree->parse($content);

	# Indexing assets listed in headers.
	my @links = $tree->find('link');
	for my $link (@links) {
		next unless $link->attr_get_i('href');
		my $href = $link->attr_get_i('href');
		store_file($urlBase, $href);
	}

	# Indexing images appearing in page.
	my @imgs = $tree->find('img');
	for my $img (@imgs) {
		next unless $img->attr_get_i('src');
		my $src = $img->attr_get_i('src');
		store_file($urlBase, $src);
		next unless $img->attr_get_i('data-src');
		my $dataSrc = $img->attr_get_i('data-src');
		next unless $dataSrc =~ /pbs\.twimg\.com/;
		store_twitter_file($dataSrc);
	}

	# Indexing scripts appearing in page.
	my @scripts = $tree->find('script');
	for my $script (@scripts) {
		next unless $script->attr_get_i('src');
		my $src = $script->attr_get_i('src');
		store_file($urlBase, $src);
	}

	# Replacing Twitter media URLS with the local ones.
	for my $dataSrc (sort keys %urlsReplacement) {
		my $localFile = $urlsReplacement{$dataSrc} // die;
		die unless $content =~ /\Q$dataSrc\E/;
		$content =~ s/\Q$dataSrc\E/$localFile/g;
	}

	# Printing reworked tree.
	$tree = HTML::Tree->new();
	$tree->parse($content);

	# Removing adds & bookmarks nodes.
	my $node1 = $tree->look_down('class'  => 'container top-ad pb-4');
	$node1->delete if $node1;
	my $node2 = $tree->look_down('class'  => 'row mb-4');
	$node2->delete if $node2;
	my $node3 = $tree->look_down('class'  => 'container');
	$node3->delete if $node3;
	my $node4 = $tree->look_down('_tag', 'div', 'class', 'mb-2 d-flex align-items-center');
	if ($node4) {
	    $node4->attr(style => 'margin-top:15px;');
	}
	my $node5 = $tree->look_down('class'  => 'container pb-5');
	$node5->delete if $node5;
	my $node6 = $tree->look_down('class'  => 'sharingfooter');
	$node6->delete if $node6;
	my $node7 = $tree->look_down('class'  => 'overlay-no-js');
	$node7->delete if $node7;
	my $node8 = $tree->look_down('class'  => 'text-center');
	$node8->delete if $node8;
	my $node9 = $tree->look_down('class'  => 'background-blue entry-support hide-premium pd-4 hide-redundant');
	$node9->delete if $node9;
	my $node10 = $tree->look_down('class' => 'container');
	$node10->delete if $node10;

	open my $out, '>:utf8', "public/$threadId.html";
	print $out $tree->as_HTML('<>&', "\t");
	close $out;
}


sub store_twitter_file  {
	my ($dataSrc) = @_;
	my (undef,
		$localFile) = split 'pbs.twimg.com', $dataSrc;
	store_file('https://pbs.twimg.com', $localFile);
	$urlsReplacement{$dataSrc} = $localFile;
}

sub store_file {
	my ($uBase, $href) = @_;

	# say $href;
	my ($filePath, $fileName, $fileExt) = path_from_url($href);
	return if $filePath eq 'https:';
	return if $fileName eq 'adsbygoogle.js';

	# Create archive path.
	make_path("public/$filePath")
	    unless (-d "public/$filePath");
	my $fileUrl   = "$uBase$href";
	my $localFile = "public/$filePath$fileName";
	$localFile    = "public/$fileName" unless $filePath;

	# Add headers to the request object
	unless (-f $localFile) {
		my $req = HTTP::Request->new(GET => $fileUrl);
		$req->header(':authority'                => 'threadreaderapp.com');
		$req->header(':method'                   => 'GET');
		$req->header(':path'                     => $href);
		$req->header(':scheme'                   => 'https');
		$req->header('accept'                    => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9');
		$req->header('accept-encoding'           => 'gzip, deflate');
		$req->header('accept-language'           => 'en-US,en;q=0.9');
		$req->header('cache-control'             => 'max-age=0');
		$req->header('if-modified-since'         => 'Tue, 16 Nov 2020 09:38:34 GMT');
		$req->header('if-none-match'             => 'W/"61937c1a-545"');
		$req->header('sec-ch-ua'                 => '"Not_A Brand";v="99", "Google Chrome";v="109", "Chromium";v="109"');
		$req->header('sec-ch-ua-mobile'          => '?0');
		$req->header('sec-ch-ua-platform'        => '"Windows"');
		$req->header('sec-fetch-dest'            => 'document');
		$req->header('sec-fetch-mode'            => 'navigate');
		$req->header('sec-fetch-site'            => 'none');
		$req->header('sec-fetch-user'            => '?1');
		$req->header('upgrade-insecure-requests' => 1);
		$req->header('user-agent'                => $userAgent);

		my $res = $ua->request($req);

		# Check if the request was successful
		if ($res->is_success) {

			# Storing content based on file type (as extrapolated from the extension).
			if (
				$fileExt eq 'css'  ||
				$fileExt eq 'svg'  ||
				$fileExt eq 'json' ||
				$fileExt eq 'js'
			) {
			    open my $fh, ">", $localFile or die $!;
			    print $fh $res->decoded_content;
			    close $fh;
			} elsif (
				$fileExt eq 'png'  ||
				$fileExt eq 'jpg'  ||
				$fileExt eq 'jpeg' ||
				$fileExt eq 'gif'
			) {
			    open my $fh, ">", $localFile or die $!;
			    binmode $fh;
			    print $fh $res->content;
			    close $fh;
			} else {
				die "fileExt : [$fileExt]";
			}
		} else {
		    die "getstore of [$fileUrl] failed with " . $res->status_line;
		}
	}
}

sub path_from_url {
	my $href = shift;
	my ($filePath, @elems) = split '\/', $href;
	my $fileName;
	return $filePath if $filePath eq 'https:';
	for my $pathElem (0 .. (scalar @elems - 2)) {
		my $elem   = $elems[$pathElem];
		$filePath .= $elem;
		$filePath .= '/';
	}
	$fileName = $elems[scalar @elems - 1];
	die unless $fileName;
	my @fElems = split '\.', $fileName;
	my $fileExt = $fElems[scalar @fElems - 1];

	return ($filePath, $fileName, $fileExt);
}