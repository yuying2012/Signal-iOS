//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import PromiseKit
import SignalServiceKit

private protocol OutgoingIndicatorsDelegate: class {
    func sendTypingMessage(forThread thread: TSThread, action: OWSTypingIndicatorAction)
}

@objc
public class OWSTypingIndicators: NSObject, OutgoingIndicatorsDelegate {

    // MARK: - Dependencies

    private var messageSender: MessageSender {
        return SSKEnvironment.shared.messageSender
    }

    // MARK: -

    private class OutgoingIndicators {
        private weak var delegate: OutgoingIndicatorsDelegate?
        private let thread: TSThread
        private var sendPauseTimer: Timer?
        private var sendRefreshTimer: Timer?

        init(delegate: OutgoingIndicatorsDelegate, thread: TSThread) {
            self.delegate = delegate
            self.thread = thread
        }

        func inputWasTyped() {
            AssertIsOnMainThread()

            if sendRefreshTimer == nil {
                // If the user types a character into the compose box, and the sendRefresh timer isn’t running:

                // Send a ACTION=TYPING message.
                delegate?.sendTypingMessage(forThread: thread, action: .started)
                // Start the sendRefresh timer for 10 seconds
                sendRefreshTimer?.invalidate()
                sendRefreshTimer = Timer.weakScheduledTimer(withTimeInterval: 10,
                                                            target: self,
                                                            selector: #selector(OutgoingIndicators.sendRefreshTimerDidFire),
                                                            userInfo: nil,
                                                            repeats: false)
                // Start the sendPause timer for 5 seconds
            } else {
                // If the user types a character into the compose box, and the sendRefresh timer is running:

                // Send nothing
                // Cancel the sendPause timer
                // Start the sendPause timer for 5 seconds again
            }

            sendPauseTimer?.invalidate()
            sendPauseTimer = Timer.weakScheduledTimer(withTimeInterval: 5,
                                                      target: self,
                                                      selector: #selector(OutgoingIndicators.sendPauseTimerDidFire),
                                                      userInfo: nil,
                                                      repeats: false)
        }

        @objc
        func sendPauseTimerDidFire() {
            AssertIsOnMainThread()

            // If the sendPause timer fires:

            // Send ACTION=STOPPED message.
            delegate?.sendTypingMessage(forThread: thread, action: .stopped)
            // Cancel the sendRefresh timer
            sendRefreshTimer?.invalidate()
            sendRefreshTimer = nil
            // Cancel the sendPause timer
            sendPauseTimer?.invalidate()
            sendPauseTimer = nil
        }

        @objc
        func sendRefreshTimerDidFire() {
            AssertIsOnMainThread()

            // If the sendRefresh timer fires:

            // Send ACTION=TYPING message
            delegate?.sendTypingMessage(forThread: thread, action: .started)
            // Cancel the sendRefresh timer
            sendRefreshTimer?.invalidate()
            // Start the sendRefresh timer for 10 seconds again
            sendRefreshTimer = Timer.weakScheduledTimer(withTimeInterval: 10,
                                                        target: self,
                                                        selector: #selector(sendRefreshTimerDidFire),
                                                        userInfo: nil,
                                                        repeats: false)
        }

        func messageWasSent() {
            AssertIsOnMainThread()

            // If the user sends the message:

            // Cancel the sendRefresh timer
            sendRefreshTimer?.invalidate()
            sendRefreshTimer = nil
            // Cancel the sendPause timer
            sendPauseTimer?.invalidate()
            sendPauseTimer = nil
        }
    }

    // Map of thread id-to-OutgoingIndicators.
    private var outgoingIndicatorsMap = [String: OutgoingIndicators]()

    private func ensureOutgoingIndicators(forThread thread: TSThread) -> OutgoingIndicators? {
        AssertIsOnMainThread()

        guard let threadId = thread.uniqueId else {
            owsFailDebug("Thread missing id")
            return nil
        }
        if let outgoingIndicators = outgoingIndicatorsMap[threadId] {
            return outgoingIndicators
        }
        let outgoingIndicators = OutgoingIndicators(delegate: self, thread: thread)
        outgoingIndicatorsMap[threadId] = outgoingIndicators
        return outgoingIndicators
    }

    @objc
    public func inputWasTyped(thread: TSThread) {
        guard let outgoingIndicators = ensureOutgoingIndicators(forThread: thread) else {
            owsFailDebug("Could not locate outgoing indicators state")
            return
        }
        outgoingIndicators.inputWasTyped()
    }

    @objc
    public func messageWasSent(thread: TSThread) {
        guard let outgoingIndicators = ensureOutgoingIndicators(forThread: thread) else {
            owsFailDebug("Could not locate outgoing indicators state")
            return
        }
        outgoingIndicators.messageWasSent()
    }

    // MARK: - OutgoingIndicatorsDelegate

    func sendTypingMessage(forThread thread: TSThread, action: OWSTypingIndicatorAction) {
        let message = OWSTypingIndicatorMessage(thread: thread, action: action)
        messageSender.sendPromise(message: message)
        .done {
            Logger.info("Outgoing typing indicator message send succeeded.")
        }.catch { error in
            Logger.error("Outgoing typing indicator message send failed: \(error).")
        }.retainUntilComplete()
    }
}
