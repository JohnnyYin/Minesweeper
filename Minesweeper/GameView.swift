//
//  GameView.swift
//  Minesweeper
//
//  Created by JohnnyYin on 16/1/30.
//  Copyright © 2016年 JohnnyYin. All rights reserved.
//

import UIKit

class GameView: UIView {
    class Square {
        enum Status {
            case hide// 隐藏
            case show// 展开
            case flag// 旗帜
            case bomb// 爆炸
        }
        let rect:CGRect
        let index:Int
        var status = Status.hide
        /** 雷数 */
        var mineNum:Int = 0;
        let rowIndex:Int
        let columnIndex:Int
        var isMine:Bool = false
        
        init(rect:CGRect, index:Int, rowIndex:Int, columnIndex:Int) {
            self.rect = rect
            self.index = index
            self.rowIndex = rowIndex
            self.columnIndex = columnIndex
        }
        
        func isHide() -> Bool {
            return self.status == Status.hide
        }
    }
    
    let MAX_MINE_NUM_PERCENT = 0.16
    let GRID_SIZE = CGFloat(40);
    var horizontalPadding:CGFloat = 0
    var verticalPadding:CGFloat = 0
    let LINE_WIDTH = CGFloat(5)
    var squares = [Square]();
    let squareBgColor = UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1.0).CGColor
    let bgColor = UIColor(red: 204/255.0, green: 204/255.0, blue: 204/255.0, alpha: 1.0).CGColor
    var drawTextAttr:Dictionary<String, AnyObject>?;
    var columnNum = 0
    var rowNum = 0
    var statusHeight:CGFloat = 0
    var scoreBarHeight:CGFloat = 30
    var gameOver = false
    var mineNum = 0
    var score = 0
    var gameStartTime:Double = 0
    var pausedTime:Int = 0
    var pausedStartTime:Double = 0
    var timer:NSTimer?
    
    weak var viewController: UIViewController?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.frame = UIScreen.mainScreen().bounds
        
        // 点击事件
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "handleTapGesture:"))
        
        //长按手势
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "handleLongpressGesture:")
        longPressGestureRecognizer.minimumPressDuration = 0.3
        self.addGestureRecognizer(longPressGestureRecognizer)
        
        let fieldColor: UIColor = UIColor.darkGrayColor()
        let fieldFont = UIFont.boldSystemFontOfSize(18)
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = NSTextAlignment.Center;
        
        drawTextAttr = [
            NSForegroundColorAttributeName: fieldColor,
            NSParagraphStyleAttributeName: paraStyle,
            NSFontAttributeName: fieldFont
        ]
        
        let sizeWithLine = GRID_SIZE + LINE_WIDTH
        statusHeight = UIApplication.sharedApplication().statusBarFrame.height;
        rowNum = Int((frame.height - statusHeight - scoreBarHeight) / sizeWithLine)
        columnNum = Int(frame.width / sizeWithLine)
        horizontalPadding = (frame.width % sizeWithLine) / 2;
        verticalPadding = ((frame.height - statusHeight - scoreBarHeight) % sizeWithLine) / 2
        
        squares = [Square](count: rowNum * columnNum, repeatedValue: Square(rect: CGRectMake(0, 0, 0, 0), index: -1, rowIndex: -1, columnIndex: -1))
        initGameData()
    }
    
    func initGameData() {
        let sizeWithLine = GRID_SIZE + LINE_WIDTH
        let squareCount = rowNum * columnNum
        let startX = horizontalPadding + LINE_WIDTH / 2
        let startY = verticalPadding + LINE_WIDTH / 2 + statusHeight + scoreBarHeight;
        for var i = 0; i < rowNum; i++ {// 行
            for var j = 0; j < columnNum; j++ {// 列
                let index = i * columnNum + j
                squares[index] = Square(rect: CGRectMake(startX + CGFloat(j) * sizeWithLine, startY + CGFloat(i) * sizeWithLine, GRID_SIZE, GRID_SIZE), index: index, rowIndex: i, columnIndex: j)
            }
        }
        
        // 放置雷
        let maxMineNum = Int(Double(squareCount) * MAX_MINE_NUM_PERCENT)
        var curMineNum = 0
        mineNum = maxMineNum
        
        func addMineNum(row:Int, column:Int) {
            if (row >= 0 && row < rowNum && column >= 0 && column < columnNum) {
                let square = squares[row * columnNum + column]
                if (!square.isMine) {
                    square.mineNum++
                }
            }
        }
        
        while (curMineNum < maxMineNum) {
            let random = Int(arc4random_uniform(UInt32(squareCount)))
            let square = squares[random]
            if (!square.isMine) {
                square.isMine = true
                addMineNum(square.rowIndex - 1, column: square.columnIndex - 1)
                addMineNum(square.rowIndex - 1, column: square.columnIndex)
                addMineNum(square.rowIndex - 1, column: square.columnIndex + 1)
                addMineNum(square.rowIndex,     column: square.columnIndex - 1)
                addMineNum(square.rowIndex,     column: square.columnIndex + 1)
                addMineNum(square.rowIndex + 1, column: square.columnIndex - 1)
                addMineNum(square.rowIndex + 1, column: square.columnIndex)
                addMineNum(square.rowIndex + 1, column: square.columnIndex + 1)
                curMineNum++
            }
        }
        
        gameStartTime = NSDate().timeIntervalSince1970
        startTimer()
    }
    
    override func didMoveToWindow() {
        for var next: UIView? = self.superview; next != nil; next = next!.superview {
            let nextResponder = next?.nextResponder()
            if nextResponder is UIViewController {
                self.viewController = nextResponder as? UIViewController
                break
            }
        }
        
        // 添加应用进入后台监听
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "applicationForegroundBackgroundChanged:",
            name: UIApplicationDidEnterBackgroundNotification,
            object: nil)
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "applicationForegroundBackgroundChanged:",
            name: UIApplicationWillEnterForegroundNotification,
            object: nil)
    }
    
    func applicationForegroundBackgroundChanged(notification: NSNotification) {
        let enterBackground = notification.name == UIApplicationDidEnterBackgroundNotification
        if (enterBackground) {
            pausedStartTime = NSDate().timeIntervalSince1970
            timer?.invalidate()
        } else {
            if !gameOver {
                startTimer()
            }
            if pausedStartTime <= 0 {
                return
            }
            pausedTime += Int(NSDate().timeIntervalSince1970 - pausedStartTime)
            pausedStartTime = 0
        }
    }
    
    override func drawRect(rect: CGRect) {
        super.drawRect(rect)
        let context:CGContextRef? = UIGraphicsGetCurrentContext() //获取画笔上下文
        CGContextSetAllowsAntialiasing(context, true) //抗锯齿设置
        CGContextSetFillColorWithColor(context, bgColor)
        CGContextSetStrokeColorWithColor(context, UIColor.whiteColor().CGColor)
        CGContextSetLineWidth(context, LINE_WIDTH) //设置画笔宽度
        var curFillColor = bgColor
        for square in squares {
            if square.index < 0 {
                continue
            }
            switch square.status {
            case .hide:
                fallthrough
            case .flag:
                if curFillColor !== bgColor {
                    curFillColor = bgColor
                    CGContextSetFillColorWithColor(context, curFillColor)
                }
                CGContextFillRect(context, square.rect)
            case .bomb:
                fallthrough
            case .show:
                if curFillColor !== squareBgColor {
                    curFillColor = squareBgColor
                    CGContextSetFillColorWithColor(context, curFillColor)
                }
                CGContextFillRect(context, square.rect)
            }
        }
        
        var flagNum = 0;
        for square in squares {
            if square.index < 0 {
                continue
            }
            switch square.status {
            case .hide:
                continue
            case .bomb:
                fallthrough
            case .flag:
                fallthrough
            case .show:
                drawTextAttr?[NSForegroundColorAttributeName] = UIColor.darkGrayColor()
                var squareStr: NSString
                if square.status == Square.Status.flag {
                    flagNum++
                    squareStr = "🚩"
                } else if square.status == Square.Status.bomb {
                    squareStr = "💥"
                } else if square.isMine {
                    squareStr = "💣"
                } else if square.mineNum > 0 {
                    squareStr = "\(square.mineNum)"
                    if square.mineNum > 5 {
                        drawTextAttr?[NSForegroundColorAttributeName] = UIColor.redColor()
                    } else if square.mineNum > 3 {
                        drawTextAttr?[NSForegroundColorAttributeName] = UIColor.blueColor()
                    } else if square.mineNum > 1 {
                        drawTextAttr?[NSForegroundColorAttributeName] = UIColor.orangeColor()
                    }
                } else {
                    continue
                }
                squareStr.drawInRect(square.rect.offsetBy(dx: 0, dy: 8), withAttributes: drawTextAttr!)
            }
        }
        
        calcScore()
        let scoreBarStr = "雷数：\(mineNum - flagNum)/\(mineNum)  时间：\(parseSpendTime())  分数：\(score)"
        drawTextAttr?[NSForegroundColorAttributeName] = UIColor.darkGrayColor()
        scoreBarStr.drawInRect(CGRectMake(0, statusHeight + scoreBarHeight / 3, self.frame.width, scoreBarHeight), withAttributes: drawTextAttr!)
    }
    
    func parseSpendTime() -> String {
        var timeStr:String = ""
        var time = Int(NSDate().timeIntervalSince1970 - gameStartTime) - pausedTime
        if time > 60 * 60 {
            let t = time / 3600
            if t < 10 {
                timeStr.appendContentsOf("0")
            }
            timeStr.appendContentsOf("\(t):")
            time = time % 3600
        }
        
        var t = time / 60
        if t < 10 {
            timeStr.appendContentsOf("0")
        }
        timeStr.appendContentsOf("\(t):")
        time = time % 60
        t = time
        
        if t < 10 {
            timeStr.appendContentsOf("0")
        }
        timeStr.appendContentsOf("\(t)")
        return timeStr
    }
    
    func expand(row:Int, column:Int) {
        if (row < 0 || row >= rowNum || column < 0 || column >= columnNum) {
            return
        }
        let checkSquare = squares[row * columnNum + column]
        if !checkSquare.isHide() || checkSquare.isMine {
            return
        }
        if checkSquare.mineNum > 0 {
            checkSquare.status = Square.Status.show
            return
        }
        checkSquare.status = Square.Status.show
        expand(checkSquare.rowIndex - 1, column: checkSquare.columnIndex - 1)
        expand(checkSquare.rowIndex - 1, column: checkSquare.columnIndex)
        expand(checkSquare.rowIndex - 1, column: checkSquare.columnIndex + 1)
        expand(checkSquare.rowIndex,     column: checkSquare.columnIndex - 1)
        expand(checkSquare.rowIndex,     column: checkSquare.columnIndex + 1)
        expand(checkSquare.rowIndex + 1, column: checkSquare.columnIndex - 1)
        expand(checkSquare.rowIndex + 1, column: checkSquare.columnIndex)
        expand(checkSquare.rowIndex + 1, column: checkSquare.columnIndex + 1)
    }
    
    func bomb(index:Int) {
        calcScore()
        gameOver = true
        timer?.invalidate()
        for s in squares {
            if s.isHide() {
                s.status = Square.Status.show
                if s.index == index {
                    s.status = Square.Status.bomb
                }
            }
        }
        showAlert("踩到地雷啦~~\n分数：\(score)")
    }
    
    // 点击事件
    func handleTapGesture(sender: UITapGestureRecognizer){
        if (sender.state == UIGestureRecognizerState.Ended) {
            if gameOver {
                restart()
                return
            }
            let point: CGPoint = sender.locationInView(self)
            for square in squares {
                let hit = square.rect.contains(point)
                if (!hit) {
                    continue
                }
                switch square.status {
                case .hide:
                    if (square.isMine) {
                        bomb(square.index)
                    } else {
                        expand(square.rowIndex, column: square.columnIndex)
                    }
                    setNeedsDisplay()
                    break
                default:
                    break
                }
            }
            checkGameStatus()
        }
    }
    
    //长按手势
    func handleLongpressGesture(sender: UILongPressGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.Began {
            let point: CGPoint = sender.locationInView(self)
            for square in squares {
                let hit = square.rect.contains(point)
                if (hit) {
                    switch square.status {
                    case .flag:
                        square.status = Square.Status.hide
                        setNeedsDisplay()
                        break
                    case .hide:
                        square.status = Square.Status.flag
                        setNeedsDisplay()
                        break
                    default:
                        break
                    }
                }
            }
            checkGameStatus()
        }
    }
    
    func checkGameStatus() {
        var successed = true
        for s in squares {
            successed = s.status == Square.Status.show || s.status == Square.Status.flag
            if !successed {
                break
            }
        }
        if successed {
            gameOver = true
            timer?.invalidate()
            calcScore()
            showAlert("成功啦~~\n分数：\(score)")
        }
    }
    
    /***
     * 计分规则：
     * 1. 正确的旗帜计5分
     * 2. 显示的空格计5分
     * 3. 时间过去5秒扣1分
     */
    func calcScore() {
        if gameOver {
            return
        }
        var baseScore = 0
        for s in squares {
            switch s.status {
            case .flag:
                baseScore += s.isMine ? 1 : 0
            case .show:
                baseScore += s.mineNum == 0 ? 1 : 0
            default:
                continue
            }
        }
        self.score = baseScore * 5 - (Int(NSDate().timeIntervalSince1970 - gameStartTime) - pausedTime) / 5
        if self.score < 0 {
            self.score = 0
        }
    }
    
    func showAlert(message:String) {
        let alertController = UIAlertController(title: "扫雷", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertActionStyle.Cancel, handler: nil)
        let resetAction = UIAlertAction(title: "重新开始", style: UIAlertActionStyle.Destructive, handler: {
            (alerts: UIAlertAction!) -> Void in
            self.restart()
        })
        
        alertController.addAction(resetAction)
        alertController.addAction(cancelAction)
        self.viewController?.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func startTimer() {
        if timer != nil {
            timer?.invalidate()
        }
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "updateTime:", userInfo: "GameTimer", repeats: true)
    }
    
    func updateTime(timer: NSTimer) {
        self.setNeedsDisplay()
    }
    
    func restart() {
        gameOver = false
        timer?.invalidate()
        score = 0
        mineNum = 0
        gameStartTime = 0
        pausedStartTime = 0
        pausedTime = 0
        initGameData()
        setNeedsDisplay()
    }
    
    deinit {
        gameOver = true
        timer?.invalidate()
    }
    
}
