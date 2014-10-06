//
//  MineGridCell.m
//  JapaneseMinesweeper
//
//  Created by Jakmir on 9/13/14.
//  Copyright (c) 2014 Jakmir. All rights reserved.
//

#import "MineGridCell.h"

@implementation MineGridCell
{
    CAGradientLayer *gradientLayer;
}

- (instancetype) initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.state = MineGridCellStateClosed;
    }
    return self;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    if (gradientLayer)
    {
        [gradientLayer removeFromSuperlayer];
    }
    CGRect rectangle = rect;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetRGBStrokeColor(context, 0.9, 0.9, 0.9, 1);
    CGContextSetLineWidth(context, 1.0);
    
    switch (self.state)
    {
        case MineGridCellStateClosed:
        {
            CGContextSetRGBFillColor(context, 0.67, 0.67, 0.67, 1);
            CGContextFillRect(context, rectangle);
        }
            break;
        case MineGridCellStateMarked:
        {
            CGContextSetRGBFillColor(context, 0.3, 0.5, 0.3, 1);
            CGContextFillRect(context, rectangle);
            UIFont* font = [UIFont systemFontOfSize:28];
            UIColor* textColor = [UIColor greenColor];
            NSDictionary* stringAttrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName:textColor};
            
            NSAttributedString* attrStr = [[NSAttributedString alloc] initWithString:@"F" attributes:stringAttrs];
            
            [attrStr drawAtPoint:CGPointMake(27.f, 18.f)];
        }
            break;
        case MineGridCellStateOpened:
        {
            CGContextSetRGBFillColor(context, 0.76, 0.76, 0.8, 1);
            CGContextFillRect(context, rectangle);
            UIFont* font = [UIFont systemFontOfSize:self.mine ? 90 : 20];
            UIColor* textColor = [UIColor whiteColor];
            NSDictionary* stringAttrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName:textColor};
            

            
            if (self.mine)
            {
                [@"*" drawAtPoint:CGPointMake(19.f, 1.f) withAttributes:stringAttrs];
            }
            else
            {
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, 0, 0);
                CGContextAddLineToPoint(context, rect.size.width, rect.size.height);
                CGContextMoveToPoint(context, rect.size.width, 0);
                CGContextAddLineToPoint(context, 0, rect.size.height);
                CGContextClosePath(context);
                CGContextDrawPath(context, kCGPathFillStroke);
                [[@(self.cellInfo.minesLeftDirection) stringValue] drawAtPoint:CGPointMake(7, 22) withAttributes:stringAttrs];
                [[@(self.cellInfo.minesRightDirection) stringValue] drawAtPoint:CGPointMake(54, 22) withAttributes:stringAttrs];
                [[@(self.cellInfo.minesTopDirection) stringValue] drawAtPoint:CGPointMake(31, 2) withAttributes:stringAttrs];
                [[@(self.cellInfo.minesBottomDirection) stringValue] drawAtPoint:CGPointMake(31, 44) withAttributes:stringAttrs];
            }
        }
            break;
        default:
            break;
    }
}

- (void) setState:(MineGridCellState)state
{
    if (_state != state)
    {
        _state = state;
        [self setNeedsDisplay];
    }
}

@end
