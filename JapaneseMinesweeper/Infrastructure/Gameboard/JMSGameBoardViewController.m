//
//  GameBoardViewController.m
//  JapaneseMinesweeper
//
//  Created by Jakmir on 9/13/14.
//  Copyright (c) 2014 Jakmir. All rights reserved.
//

#import "JMSGameBoardViewController.h"
#import "JMSMineGridCell.h"
#import "JMSMainViewController.h"
#import "JMSGameModel.h"
#import "JMSAlteredCellInfo.h"
#import "UIColor+ColorFromHexString.h"
#import <GameKit/GKLocalPlayer.h>
#import <GameKit/GKScore.h>
#import <GameKit/GKGameCenterViewController.h>
#import "JMSLeaderboardManager.h"
#import "JMSSoundHelper.h"
#import "JMSPopoverPresentationController.h"
#import "JMSTutorialManager.h"
#import "JMSGameboardView.h"
#import "JMSGameModel+TutorialWrapper.h"
#import "UIView+MakeFitToEdges.h"

static NSString * kLeaderboardId = @"JMSMainLeaderboard";

@interface JMSGameBoardViewController ()

@property (nonatomic, readonly) JMSGameboardView *gameboardView;
@property (nonatomic, readonly) JMSTutorialManager *tutorialManager;
@property (nonatomic) BOOL shouldOpenCellInZeroDirection;
@property (nonatomic) BOOL initialTapPerformed;

@end

@implementation JMSGameBoardViewController

- (JMSGameboardView *)gameboardView {
    if ([self.view isKindOfClass:[JMSGameboardView class]]) {
        return (JMSGameboardView *)self.view;
    }
    return nil;
}

- (void)addGestureRecognizers {
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(singleTap:)];
    [self.gameboardView.mineGridView addGestureRecognizer:tapRecognizer];

    UILongPressGestureRecognizer *longTapRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                    action:@selector(longTap:)];
    CGFloat minimumPressDuration = [[JMSSettings shared] minimumPressDuration];
    longTapRecognizer.minimumPressDuration = minimumPressDuration;
    [self.gameboardView.mineGridView addGestureRecognizer:longTapRecognizer];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)importFromGameSession {
    self.initialTapPerformed = YES;
    
    JMSGameModel *gameSessionInfo = self.mainViewController.gameModel;
    [gameSessionInfo registerObserver:self];
    
    [self.gameboardView.mineGridView importFromGameboardMap:gameSessionInfo.mapModel.map];
    [self.gameboardView fillWithModel:gameSessionInfo];
}

- (void)createNewGame {
    self.initialTapPerformed = NO;
    
    NSUInteger level = [[JMSSettings shared] level];
    NSArray *map = [self.gameboardView.mineGridView exportMap];
    JMSGameModel *gameModel = [[JMSGameModel alloc] initWithLevel:level map:map];
    [gameModel registerObserver:self];
    self.gameModel = gameModel;
    [self.gameboardView fillWithModel:gameModel];
}

- (void)createTutorialGame {
    self.initialTapPerformed = YES;
    
    NSUInteger level = [[JMSSettings shared] level];
    NSArray *map = [self.gameboardView.mineGridView exportMap];
    JMSGameModel *gameModel = [[JMSGameModel alloc] initWithLevel:level map:map];
    [gameModel registerObserver:self];
    [gameModel fillTutorialMapWithLevel:gameModel.level];
    self.gameModel = gameModel;
    [self.gameboardView fillWithModel:gameModel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if ([[JMSSettings shared] shouldLaunchTutorial]) {
        [self createTutorialGame];
        _tutorialManager = [[JMSTutorialManager alloc] initWithGameboardController:self
                                                                              size:self.gameboardView.resultsView.bounds.size];
    }
    else {
        if (self.mainViewController.gameModel) {
            [self importFromGameSession];
        }
        else {
            [self createNewGame];
        }
    }
    self.shouldOpenCellInZeroDirection = [[JMSSettings shared] shouldOpenSafeCells];
    
    [self configureUI];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view bringSubviewToFront:self.gameboardView.ivSnapshot];
    [self.gameboardView.ivSnapshot setImage:self.mainViewController.mineGridSnapshot];
    [self.gameboardView.ivSnapshot setHidden:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.gameboardView.mineGridView refreshCells];
    [self.gameboardView.ivSnapshot setHidden:YES];

    [self addGestureRecognizers];
    
    if ([self.tutorialManager shouldLaunchTutorial]) {
        [self.tutorialManager moveToNextStep];
    }
}

- (void)removeGestureRecognizers {
    for (UIGestureRecognizer *gestureRecognizer in self.gameboardView.mineGridView.gestureRecognizers) {
        [self.gameboardView.mineGridView removeGestureRecognizer:gestureRecognizer];
    }
}

- (void)configureUI {
    BOOL tutorialFinished = self.tutorialManager ? self.tutorialManager.isFinished : YES;
    [self.gameboardView updateMenuWithFinishedTutorial:tutorialFinished
                                          gameFinished:self.gameModel.isGameFinished];
    UIColor *patternColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"wallpaper"]];
    [self.gameboardView.resultsView setBackgroundColor:patternColor];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self removeGestureRecognizers];
}

#pragma mark - Gameboard control methods

- (void)finalizeGame {
    BOOL tutorialFinished = self.tutorialManager ? self.tutorialManager.isFinished : YES;
    [self.gameboardView updateMenuWithFinishedTutorial:tutorialFinished
                                          gameFinished:self.gameModel.isGameFinished];
}

#pragma mark - handle taps

- (void)singleTap:(UIGestureRecognizer *)gestureRecognizer {
    if (self.gameModel.gameFinished) {
        return;
    }
    
    CGPoint coord = [gestureRecognizer locationInView:self.gameboardView.mineGridView];
    
    JMSPosition position = [self.gameboardView.mineGridView cellPositionWithCoordinateInside:coord];
    
    // TODO: simplify this long condition
    if (position.row == NSNotFound ||
        position.column == NSNotFound ||
        ([self.tutorialManager shouldLaunchTutorial] &&
         ![self.tutorialManager isFinished] &&
         ![self.tutorialManager isAllowedWithAction:JMSAllowedActionsClick position:position])) return;
    
    if (!self.initialTapPerformed) {
        
        [self.gameModel fillMapWithLevel:self.gameModel.level exceptPosition:position];

        self.initialTapPerformed = YES;
    }
    
    if ([self.gameModel isMinePresentAtPosition:position]) {
        [self.gameModel openCellWithPosition:position];
        return;
    }
    else {
    // TODO: simplify this long condition
        BOOL shouldOpenSafeCells = (![self.tutorialManager shouldLaunchTutorial] && self.shouldOpenCellInZeroDirection) ||
                                    ([self.tutorialManager shouldLaunchTutorial] && self.tutorialManager.currentStep >= JMSTutorialStepLastCellClick);

        BOOL isAnythingOpened = [self.gameModel openInZeroDirectionsFromPosition:position
                                                             shouldOpenSafeCells:shouldOpenSafeCells];

        if (!isAnythingOpened) {
            return;
        }

        if ([self.tutorialManager shouldLaunchTutorial] && !self.tutorialManager.isFinished) {
            [self.tutorialManager completeTaskWithPosition:position];
        }
    }
}

- (void)longTap:(UIGestureRecognizer *)gestureRecognizer {
    if (self.gameModel.isGameFinished || gestureRecognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    CGPoint touchLocation = [gestureRecognizer locationInView:self.gameboardView.mineGridView];
    JMSPosition position = [self.gameboardView.mineGridView cellPositionWithCoordinateInside:touchLocation];
        
    if (position.row == NSNotFound ||
        position.column == NSNotFound ||
        ([self.tutorialManager shouldLaunchTutorial] &&
         ![self.tutorialManager isFinished] &&
         ![self.tutorialManager isAllowedWithAction:JMSAllowedActionsMark position:position])) {
            return;
        }
        
    if ([self.tutorialManager shouldLaunchTutorial]) {
        if ([self.tutorialManager taskCompletedWithPosition:position]) {
            return;
        }
        else {
            [self.tutorialManager completeTaskWithPosition:position];
        }
    }
        
    [self.gameModel toggleMarkWithPosition:position];
}

- (void)showPlayAgainPrompt {
    __weak JMSGameBoardViewController *weakSelf = self;

    JMSMessageBoxView *alertView = [[JMSMessageBoxView alloc] initWithFrame:CGRectZero];
    [alertView setOnButtonTouchUpInside:^{
        [weakSelf resetGame];
    }];
    [self.view makeFitToEdges:alertView];
    [alertView show];
}

#pragma mark - Upper Menu Actions

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
}

- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    return YES;
}

- (IBAction)backToMainMenu {
    if (self.initialTapPerformed && !self.gameModel.isGameFinished) {
        [self.gameModel unregisterObserver:self];

        self.mainViewController.gameModel = self.gameModel;
        self.mainViewController.mineGridSnapshot = [self.gameboardView mineGridViewSnapshot];
    }
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (IBAction)resetGameClicked {
    if (!self.initialTapPerformed) {
        return;
    }

    if (self.gameModel.isGameFinished) {
        [self resetGame];
        return;
    }

    UIAlertController *resetGameController = [UIAlertController alertControllerWithTitle:nil
                                                                                 message:nil
                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *confirmResetString = NSLocalizedString(@"Confirm reset", @"Confirm reset - popover button title");
    UIAlertAction *alertActionYes = [UIAlertAction actionWithTitle:confirmResetString style:UIAlertActionStyleDestructive
                                                               handler:^(UIAlertAction *action) {
                                                                   [self resetGame];
                                                               }];
    [resetGameController addAction:alertActionYes];
    [resetGameController setModalPresentationStyle:UIModalPresentationPopover];
    
    UIPopoverPresentationController *popPresenter = [resetGameController popoverPresentationController];
    popPresenter.sourceView = self.gameboardView.btnResetGame;
    popPresenter.sourceRect = self.gameboardView.btnResetGame.bounds;
    popPresenter.delegate = self;
    [self presentViewController:resetGameController animated:YES completion:nil];
}

- (void)resetGame {
    [self.gameboardView resetGame];
    [self.gameModel unregisterObserver:self];
    self.gameModel = nil;
    [self.mainViewController setGameModel:self.gameModel];
    [self.mainViewController setMineGridSnapshot:nil];
    [self createNewGame];
    [self.gameboardView updateMenuWithFinishedTutorial:YES gameFinished:NO];
}
#pragma mark - Submit results

- (void)postScore {
    [self postScoreLocally];
    if ([[GKLocalPlayer localPlayer] isAuthenticated]) {
        [self postScoreToGameCenter];
    }
}

- (void)postScoreLocally {
    [[[JMSLeaderboardManager alloc] init] postGameScore:lroundf(self.gameModel.score)
                                                  level:self.gameModel.level
                                               progress:self.gameModel.progress];
}

- (void)postScoreToGameCenter {
    // Report the high score to Game Center
    GKScore *scoreReporter = [[GKScore alloc] initWithLeaderboardIdentifier:kLeaderboardId
                                                                     player:[GKLocalPlayer localPlayer]];
    scoreReporter.value = lroundf(self.gameModel.score);

    [GKScore reportScores:@[scoreReporter] withCompletionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"Failed to report score. Reason is: %@", error.localizedDescription);
        }
        else {
            NSLog(@"Reported score successfully");
        }
    }];
}


#pragma mark - Observer methods

- (void)cellsChanged:(NSArray *)alteredCellsCollection {
    for (JMSAlteredCellInfo *alteredCellModel in alteredCellsCollection) {
        [self.gameboardView.mineGridView updateCellWithAlteredCellModel:alteredCellModel];
    }
    [self.gameboardView fillWithModel:self.gameModel];
}

- (void)flagAdded {
    [self flagToggled];
}

- (void)flagRemoved {
    [self flagToggled];
}

- (void)flagToggled {
    [[JMSSoundHelper shared] playSoundWithAction:JMSSoundActionPutFlag];
}

- (void)ranIntoMine {
    [[JMSSoundHelper shared] playSoundWithAction:JMSSoundActionGameFailed];
    [self postScore];
    [self finalizeGame];
    [self.mainViewController setGameModel:nil];
    [self.mainViewController setMineGridSnapshot:nil];
}

- (void)cellSuccessfullyOpened {
    [[JMSSoundHelper shared] playSoundWithAction:JMSSoundActionCellTap];
}

- (void)levelCompleted {
    [[JMSSoundHelper shared] playSoundWithAction:JMSSoundActionLevelCompleted];
    [self postScore];
    [self finalizeGame];
    [self showPlayAgainPrompt];
}

@end
