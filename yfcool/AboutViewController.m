//
//  AboutViewController.m
//  yfcool
//
//  Created by apple on 2022/8/14.
//

#import "AboutViewController.h"
#import "SDAutoLayout.h"

@interface AboutViewController ()

@end

@implementation AboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setAutoLayout];
    
    // Do any additional setup after loading the view.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
-(void)setAutoLayout{
    
    [self.view setBackgroundColor:[UIColor colorWithRed:172.0/255 green:224.0/255 blue:255.0/255 alpha:1]];
    
   // float interval = self.view.height/18;
    
    UIButton *btBack = [[UIButton alloc]init];
    [self.view addSubview:btBack];
    btBack.sd_layout
        .topSpaceToView(self.view, 16)
        .leftSpaceToView(self.view, 16)
        .heightRatioToView(self.view, 0.04)
        .widthEqualToHeight(1);
    [btBack setBackgroundImage:[UIImage imageNamed:@"back"] forState:UIControlStateNormal];
    [btBack addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel  *label1 = [[UILabel alloc]init];
    [self.view addSubview:label1];
    label1.text = @"About Device";
    label1.sd_layout
        .centerXEqualToView(self.view)
        .topSpaceToView(self.view, 32);
    [label1 setFont:[UIFont fontWithName:@"Arial" size:28]];
    [label1 setTextColor:[UIColor brownColor]];
    [label1 setSingleLineAutoResizeWithMaxWidth:200];
    
    
    UIImageView *ivAbout =[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"about.jpg"]];
    [self.view addSubview:ivAbout];
    ivAbout.sd_layout
        .topSpaceToView(btBack, 32)
        .leftSpaceToView(self.view, 16)
        .rightSpaceToView(self.view, 16)
        .bottomSpaceToView(self.view, 32);
}

-(void)back:(id)sender{
    [self dismissViewControllerAnimated:YES completion:^{
            NSLog(@"return to main page");
    }];
}

@end
