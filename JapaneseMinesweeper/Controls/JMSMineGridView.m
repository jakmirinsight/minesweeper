//
//  MineGridView.m
//  JapaneseMinesweeper
//
//  Created by Jakmir on 9/13/14.
//  Copyright (c) 2014 Jakmir. All rights reserved.
//

#import "JMSMineGridView.h"
#import "JMSMineGridCell.h"
#import "UIColor+ColorFromHexString.h"
#import "JMSMineGridCellInfo.h"
#import "JMSGameSessionInfo.h"

const NSInteger count = 10;
const NSInteger padding = 19;
const NSInteger spacing = 1;

@implementation JMSMineGridView
{
    CALayer *layer;
    NSMutableArray *highlightedAreas;
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        [self prepareCells];
        [self prepareBackground];
        highlightedAreas = [NSMutableArray array];
    }
    return self;
}

- (void)refreshCells
{
    NSLog(@"%s", __FUNCTION__);
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate date]];
    for (int col = 0; col < count; col++)
    {
        for (int row = 0; row < count; row++)
        {
            JMSMineGridCell *cell = self.gameboard.map[col][row];
            if (cell.state != MineGridCellStateClosed)
            {
                [cell setNeedsDisplay];
            }
        }
    }
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate date]];
}

- (void)refreshAllCells
{
    NSLog(@"%s", __FUNCTION__);
    
    for (int col = 0; col < count; col++)
    {
        for (int row = 0; row < count; row++)
        {
            JMSMineGridCell *cell = self.gameboard.map[col][row];
            if (cell.state != MineGridCellStateOpened)
            {
                [cell setNeedsDisplay];
            }
        }
    }
}

- (NSInteger)markMines
{
    return [self.gameboard markMines];
}

- (void) resetGame
{
    for (int col = 0; col < count; col ++)
    {
        for (int row = 0; row < count; row++)
        {
            JMSMineGridCell *cell = self.gameboard.map[col][row];
            cell.mine = NO;
            cell.state = MineGridCellStateClosed;
            
        }
    }
    _gameFinished = NO;
    [self refreshAllCells];
}

- (void) prepareBackground
{
    self.backgroundColor = [UIColor whiteColor];
}

- (void) prepareCells
{
    NSMutableArray *columns = [NSMutableArray array];
    
    NSInteger dimensionSize = (self.frame.size.width - 2 * padding - (count - 1) * spacing) / count;
    CGSize size = CGSizeMake(dimensionSize, dimensionSize);
    CGVector offset = CGVectorMake(padding, padding);
    for (int col = 0; col < count; col++)
    {
        NSMutableArray *line = [NSMutableArray array];
        for (int row = 0; row < count; row++)
        {
            CGRect frame = CGRectMake((size.width + spacing) * col + offset.dx,
                                      (size.height + spacing) * row + offset.dy,
                                      size.width,
                                      size.height);
            JMSMineGridCell *mineGridCell = [[JMSMineGridCell alloc] initWithFrame:frame];
            mineGridCell.mineGridView = self;
            [line addObject:mineGridCell];
            
            [self addSubview:mineGridCell];
        }
        [columns addObject:line];
    }
    
    _gameboard = [[JMSMineGrid alloc] init];
    _gameboard.map = columns;
}

- (void) fillMapWithLevel:(NSUInteger)level exceptPosition:(JMSPosition)position
{
    [self.gameboard fillMapWithLevel:level exceptPosition:position];
}

- (void) fillTutorialMapWithLevel:(NSUInteger)level
{
    [self.gameboard fillTutorialMapWithLevel:level];
}

- (CGFloat)bonus:(JMSPosition)position
{
    return [self.gameboard bonus:position];
}

- (NSInteger) cellsCount
{
    return self.gameboard.rowCount * self.gameboard.colCount;
}

- (NSInteger) cellsLeftToOpen
{
    return self.gameboard.cellsLeftToOpen;
}

- (JMSMineGridCell *)cellWithCoordinateInside: (CGPoint)point
{
    JMSMineGridCell *cell = nil;
    JMSPosition position = [self cellPositionWithCoordinateInside:point];
    if (position.row != NSNotFound && position.column != NSNotFound)
    {
        cell = self.gameboard.map[position.column][position.row];
    }
    
    return cell;
}

- (JMSPosition)cellPositionWithCoordinateInside: (CGPoint)point
{
    CGVector offset = CGVectorMake(padding, padding);
    NSInteger dimensionSize = (self.frame.size.width - 2 * padding - (count - 1) * spacing) / count;
    CGPoint relativePoint = CGPointMake(point.x - offset.dx, point.y - offset.dy);
    int col = (int)relativePoint.x / (dimensionSize + spacing);
    int row = (int)relativePoint.y / (dimensionSize + spacing);
    BOOL clickedInField = CGRectContainsPoint(CGRectMake(0, 0, (dimensionSize + spacing) * count, (dimensionSize + spacing) * count),
                                              relativePoint);
    BOOL clickedInCell = (int)relativePoint.x % (dimensionSize + spacing) < dimensionSize &&
    (int)relativePoint.y % (dimensionSize + spacing) < dimensionSize;
    
    JMSPosition position = {.row = NSNotFound, .column = NSNotFound};
    
    if (clickedInField && clickedInCell)
    {
        position.row = row;
        position.column = col;
    }
    
    return position;
}


- (JMSMineGridCellState) cellState:(JMSPosition)position
{
    return [self.gameboard cellState:position];
}

- (JMSMineGridCellNeighboursSummary)cellSummaryWithPosition:(JMSPosition)position
{
    return [self.gameboard cellSummary:position];
}

- (BOOL) clickedWithCoordinate: (CGPoint)point
{
    if (self.gameFinished) return NO;
    
    JMSMineGridCell *cell = [self cellWithCoordinateInside:point];
    
    if (cell)
    {
        [cell setState:MineGridCellStateOpened];
        return cell.mine;
    }
    
    return NO;
}

- (void) finalizeGame
{
    _gameFinished = YES;
    [self refreshAllCells];
}

- (NSUInteger) markUncoveredMines
{
    NSUInteger count = 0;
    for (NSArray *column in self.gameboard.map)
    {
        for (JMSMineGridCell *cell in column)
        {
            if (cell.mine && cell.state == MineGridCellStateClosed)
            {
                [cell setState:MineGridCellStateMarked];
                count++;
            }
        }
    }
    return count;
}

- (void) longTappedWithCoordinate:(CGPoint)point
{
    if (self.gameFinished) return;
    
    JMSMineGridCell *cell = [self cellWithCoordinateInside:point];
    
    if (cell)
    {
        switch (cell.state)
        {
            case MineGridCellStateMarked:
                [cell setState:MineGridCellStateClosed];
                break;
            case MineGridCellStateClosed:
                [cell setState:MineGridCellStateMarked];
                break;
            default:
                break;
        }
    }
}

- (void)drawRect:(CGRect)rect
{
    NSLog(@"%s", __FUNCTION__);
    
    [super drawRect:rect];
}

#pragma mark - Export/Import methods

- (NSArray *)exportMap
{
    NSMutableArray *localMap = [NSMutableArray array];
    for (NSArray *vector in self.gameboard.map)
    {
        NSMutableArray *localVector = [NSMutableArray array];
        for (JMSMineGridCell *cell in vector)
        {
            [localVector addObject:cell.exportCell];
        }
        [localMap addObject:localVector];
    }
    return localMap;
}

- (void)importMap:(NSArray *)gameboardMap
{
    NSLog(@"%s", __FUNCTION__);
    
    for (int col = 0; col < count; col++)
    {
        for (int row = 0; row < count; row++)
        {
            JMSMineGridCell *cell = self.gameboard.map[col][row];
            JMSMineGridCellInfo *cellInfo = gameboardMap[col][row];
            [cell import:cellInfo];
        }
    }
}

#pragma mark - Higlight/Unhighlight methods

- (void)highlightCellWithPosition:(JMSPosition)position
{
    JMSMineGridCell *cell = self.gameboard.map[position.column][position.row];

    CGRect rect = CGRectInset(cell.frame, 1, 1);
    CAShapeLayer *antLayer = [CAShapeLayer layer];
    [antLayer setBounds:rect];
    [antLayer setPosition:CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect))];
    [antLayer setFillColor:[[UIColor colorFromInteger:0x3f00ceef] CGColor]];
    [antLayer setStrokeColor:[[UIColor blueColor] CGColor]];
    [antLayer setLineWidth:1];
    [antLayer setLineJoin:kCALineJoinRound];
    [antLayer setLineDashPattern:@[@10, @4]];
        
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, rect);
    [antLayer setPath:path];
    CGPathRelease(path);
        
    [self.layer addSublayer:antLayer];
    
    CABasicAnimation *dashAnimation;
    dashAnimation = [CABasicAnimation animationWithKeyPath:@"lineDashPhase"];
        
    [dashAnimation setFromValue:@0];
    [dashAnimation setToValue:@14];
    [dashAnimation setDuration:0.5f];
    [dashAnimation setRepeatCount:10000];
    
    [antLayer addAnimation:dashAnimation forKey:@"linePhase"];
    
    [highlightedAreas addObject:antLayer];
}

- (void)removeHighlights
{
    [highlightedAreas enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CAShapeLayer *lyr = obj;
        [lyr removeFromSuperlayer];
    }];
    
    [highlightedAreas removeAllObjects];
}

@end