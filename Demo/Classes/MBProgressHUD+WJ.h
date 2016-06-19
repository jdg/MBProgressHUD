
//  Created by bringbird on 16/5/9.
//  Copyright © 2015年 韦明杰. All rights reserved.
//

#import "MBProgressHUD.h"

@interface MBProgressHUD (WJ)

/**
 *  展示成功提示框到指定的 View 上
 *
 *  @param success 成功提示信息
 *  @param view    指定的View
 */
+ (void)showSuccess:(NSString *)success toView:(UIView *)view;

/**
 *  展示错误提示框到指定的 View 上
 *
 *  @param success 错误提示信息
 *  @param view    指定的View
 */
+ (void)showError:(NSString *)error toView:(UIView *)view;

/**
 *  展示提示信息到指定的View上
 *
 *  @param message 提示信息
 *  @param view    指定的View
 *
 *  @return MBProgressHUD
 */
+ (MBProgressHUD *)showMessage:(NSString *)message toView:(UIView *)view;

/**
 *  展示纯文本的提示框
 *
 *  @param message 提示信息
 *  @param delay   延迟隐藏时间
 */
+ (void)showMessage:(NSString *)message afterDelay:(NSTimeInterval)delay;

/**
 *  展示错误提示信息框
 *
 *  @param error 错误提示信息
 *  @param delay 延迟隐藏时间
 */
+ (void)showError:(NSString *)error afterDelay:(NSTimeInterval)delay;

/**
 *  展示成功提示信息框
 *
 *  @param error 成功提示信息
 *  @param delay 延迟隐藏时间
 */
+ (void)showSuccess:(NSString *)success afterDelay:(NSTimeInterval)delay;

/**
 *  展示成功信息的提示框
 *
 *  @param error 成功提示信息
 */
+ (void)showSuccess:(NSString *)success;

/**
 *  展示错误信息的提示框
 *
 *  @param error 错误提示信息
 */
+ (void)showError:(NSString *)error;

/**
 *  展示具有提示信息的菊花样式提示框
 *
 *  @param message 提示信息
 */
+ (MBProgressHUD *)showMessage:(NSString *)message;
/**
 *  隐藏提示框
 */
+ (void)hideHUDForView:(UIView *)view;
/**
 *  隐藏提示框
 */
+ (void)hideHUD;

@end
