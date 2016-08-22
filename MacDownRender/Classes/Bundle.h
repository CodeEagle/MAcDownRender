//
//  Bundle.h
//  
//
//  Created by LawLincoln on 16/8/22.
//
//

#import <Foundation/Foundation.h>

@interface Bundle : NSObject
+ (NSBundle*) Base;
+ (NSBundle*) Template;
+ (NSBundle*) Prism;
+ (NSBundle*) MathJax;
+ (NSBundle*) Chart;
+ (NSBundle*) Extensions;
+ (NSBundle* )Resources;
+ (NSBundle *)bundleWith:(NSString*)name;
@end
