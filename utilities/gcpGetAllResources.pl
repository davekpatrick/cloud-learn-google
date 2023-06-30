#!/usr/bin/perl -w
# requires: gcloud binary
#           cloudasset.googleapis.com API
use strict;
use warnings;
use IO::Handle;
use utf8;
use JSON;
use File::Path qw( make_path );
# variables
binmode STDOUT, ":utf8"; 
my $dataDirectory = 'data';
my %gcpProjectResources = ();
my $projectCount = 0;
my $projectAssetCount = 0;
my $projectList = qx( gcloud projects list --format='value(projectId)' );
# ensure we have a "data" directory to store the results
if ( ! -d $dataDirectory ) {
    make_path $dataDirectory or die "Failed to create path: $dataDirectory";
}
# loop through all projects accessible to the current user
foreach my $projectId (split /[\n]+/, $projectList) {
  print "projectId:[$projectId]\n";
  $projectCount++;
  # ensure we have the cloudasset.googleapis.com API enabled
  my $enableApi = qx( gcloud services enable cloudasset.googleapis.com );
  if ( $enableApi =~ /successfully/ || $enableApi eq '' ) {
    print "cloudasset.googleapis.com API enabled\n";
  }
  # log all assess and details to a file
  $projectAssetCount = 0;
  open( my $FILE_gcpProjectResources, '>', "$dataDirectory/gcp_${projectId}_resources.json" ) or die "Could not open file $!";
  # get all assets for the project
  my $assetList = qx( gcloud asset list --project=$projectId --format='csv[no-heading](name,assetType)' );
  foreach my $asset (split /[\n]+/, $assetList) {
    $projectAssetCount++;
    my $assetName = (split /,/, $asset)[0];
    my $assetType = (split /,/, $asset)[1];
    # count asset types
    if ( !exists $gcpProjectResources{$projectId}{$assetType} ) {
      $gcpProjectResources{$projectId}{$assetType}{"type"} = $assetType;
      $gcpProjectResources{$projectId}{$assetType}{"count"} = 1;
    } else {
      $gcpProjectResources{$projectId}{$assetType}{"count"}++;
    }
    # capture asset
    $gcpProjectResources{$projectId}{$assetType}{"assets"}[$gcpProjectResources{$projectId}{$assetType}{"count"} - 1]{"index"} = $gcpProjectResources{$projectId}{$assetType}{"count"};
    $gcpProjectResources{$projectId}{$assetType}{"assets"}[$gcpProjectResources{$projectId}{$assetType}{"count"} - 1]{"name"} = $assetName;
    print sprintf('assetType:[%s] count:[%s]', $assetType, $gcpProjectResources{$projectId}{$assetType}{"count"} );
    # get resource details
    my $assetResource = qx( gcloud asset search-all-resources --scope=projects/$projectId --query='name=$assetName' --read-mask='*' --format=json );
    my $assetResourceJson = decode_json($assetResource);
    # capture resorce details
    $gcpProjectResources{$projectId}{$assetType}{"assets"}[$gcpProjectResources{$projectId}{$assetType}{"count"} - 1]{"createTime"} = $assetResourceJson->[0]{"createTime"};
    $gcpProjectResources{$projectId}{$assetType}{"assets"}[$gcpProjectResources{$projectId}{$assetType}{"count"} - 1]{"resource"} = $assetResourceJson->[0]{"versionedResources"}[0]{"resource"};
    print "\r" . ' ' x 120 . "\r";
  } 
  # write out the project asset and resource details
  my $json = encode_json( $gcpProjectResources{$projectId} );
  print $FILE_gcpProjectResources $json;
  close( $FILE_gcpProjectResources );
  print "projectAssetCount:[$projectAssetCount]\n";
}
# 
print "projectCount:[$projectCount]\n";
exit 0;