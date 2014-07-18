//
//  TPLTEcgRecordsViewController.m
//  TP
//
//  Created by Dmitri Vorobiev on 18/06/14.
//  Copyright (c) 2014 Electria. All rights reserved.
//

#import "TPLTEcgRecordsViewController.h"
#import "TPLTRecordViewController.h"

@interface TPLTEcgRecordsViewController ()

@property (nonatomic, strong) NSMutableArray *fileList;

// FIXME maybe we will factor this out to another class
@property (nonatomic, strong) NSString *ecgRecordsPath;

@end

@implementation TPLTEcgRecordsViewController

@synthesize fileList;
@synthesize ecgRecordsPath;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // display an Edit button in the navigation bar for this view controller.
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    ecgRecordsPath = [documentsPath stringByAppendingPathComponent:@"ecg"];
    NSLog(@"ecg path %@", ecgRecordsPath);
    
    if (![fileManager fileExistsAtPath:ecgRecordsPath]) {
        
        // FIXME GRACEFULLY HANDLE THIS
        // FOR NOW WE ASSUME THIS DIR EXISTS
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    NSLog(@"queried the number of sections");
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    NSLog(@"queried the number of rows");

    fileList = [[NSMutableArray alloc] init];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:ecgRecordsPath error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension = 'log'"];
    
    for (NSString *f in [contents filteredArrayUsingPredicate:predicate]) {
        NSLog(@"found log file %@", f);
        [fileList addObject:f];
    }
    
    return [fileList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ECGRecord" forIndexPath:indexPath];

    NSString *s = [[fileList objectAtIndex:indexPath.row] stringByDeletingPathExtension];
    NSTimeInterval i = [s doubleValue];
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:i];

    cell.textLabel.text = [NSDateFormatter localizedStringFromDate:d
                                                         dateStyle:NSDateFormatterMediumStyle
                                                         timeStyle:NSDateFormatterMediumStyle];

    return cell;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSLog(@"deleting row %d", indexPath.row);
        
        NSLog(@"deleting file %@", [fileList objectAtIndex:indexPath.row]);
        NSLog(@"ecg records path is %@", ecgRecordsPath);
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *fileToBeDeleted = [ecgRecordsPath stringByAppendingPathComponent:[fileList objectAtIndex:indexPath.row]];
        
        NSLog(@"will now delete file %@", fileToBeDeleted);
        
        NSError *error = nil;
        if (![fileManager removeItemAtPath:fileToBeDeleted error:&error]) {
            NSLog(@"[Error] %@ (%@)", error, fileToBeDeleted);
        }
        
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"preparing for segue");
    NSIndexPath *p = [self.tableView indexPathForSelectedRow];
    NSLog(@"selected row is %ld where file name is %@", (long)p.row, [fileList objectAtIndex:p.row]);
        
    TPLTRecordViewController *destination = [segue destinationViewController];
    destination.fileName = [fileList objectAtIndex:p.row];
}
@end
