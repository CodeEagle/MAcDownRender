//
//  Bundle.m
//  
//
//  Created by LawLincoln on 16/8/22.
//
//

#import "Bundle.h"

@implementation Bundle

+ (NSBundle* )Base {
    NSBundle *bundle = [NSBundle bundleForClass:Bundle.class];
    NSString *path = [bundle pathForResource:@"MacDownRender" ofType:@"bundle"];
    NSBundle *b = [NSBundle bundleWithPath:path];
    return b;
}

+ (NSBundle *)bundleWith:(NSString*)name {
    NSString *t = [Bundle.Base pathForResource:name ofType:nil];
    NSBundle *tt = [NSBundle bundleWithPath:t];
    return tt;
}

+ (NSBundle *)Template {
    return [Bundle bundleWith:@"Template"];
}
+ (NSBundle* )Resources {
    return [Bundle bundleWith:@"Resources"];
}
+ (NSBundle *)Prism {
    return [Bundle bundleWith:@"prism"];
}
+ (NSBundle *)MathJax {
    return [Bundle bundleWith:@"MathJax"];
}
+ (NSBundle *) Chart {
    return [Bundle bundleWith:@"FlowChartSequence"];
}
+ (NSBundle *)Extensions {
    return [Bundle bundleWith:@"Extensions"];
}
@end
