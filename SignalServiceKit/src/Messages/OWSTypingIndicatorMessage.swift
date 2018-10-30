//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc public enum OWSTypingIndicatorAction: Int {
    case started
    case stopped
}

@objc
public class OWSTypingIndicatorMessage: TSOutgoingMessage {
    private let action: OWSTypingIndicatorAction

    // MARK: Initializers

    @objc
    public init(thread: TSThread,
                action: OWSTypingIndicatorAction) throws {
        self.action = action

        super.init(outgoingMessageWithTimestamp: NSDate.ows_millisecondTimeStamp(),
                   in: thread,
                   messageBody: nil,
                   attachmentIds: NSMutableArray(),
                   expiresInSeconds: 0,
                   expireStartedAt: 0,
                   isVoiceMessage: false,
                   groupMetaMessage: .unspecified,
                   quotedMessage: nil,
                   contactShare: nil)
    }

    @objc
    public required init!(coder: NSCoder) {
        self.action = .started
        super.init(coder: coder)
    }

    @objc
    public required init(dictionary dictionaryValue: [AnyHashable: Any]!) throws {
        self.action = .started
        try super.init(dictionary: dictionaryValue)
    }

    @objc
    public override func shouldSyncTranscript() -> Bool {
        return false
    }

    @objc
    public override var isSilent: Bool {
        return true
    }

    @objc
    public override var isOnline: Bool {
        return true
    }

    private func protoAction(forAction action: OWSTypingIndicatorAction) -> SSKProtoTypingMessage.SSKProtoTypingMessageAction {
        switch action {
        case .started:
            return .started
        case .stopped:
            return .stopped
        }
    }

    @objc
    public override func buildPlainTextData(_ recipient: SignalRecipient) -> Data? {

        let typingBuilder = SSKProtoTypingMessage.builder(timestamp: self.timestamp,
                                                          action: protoAction(forAction: action))

        if let groupThread = self.thread as? TSGroupThread {
            typingBuilder.setGroupID(groupThread.groupModel.groupId)
        }

        let contentBuilder = SSKProtoContent.builder()

        do {
            contentBuilder.setTypingMessage(try typingBuilder.build())

            let data = try contentBuilder.buildSerializedData()
            return data
        } catch let error {
            owsFailDebug("failed to build content: \(error)")
            return nil
        }
    }

    // MARK: TSYapDatabaseObject overrides

    @objc
    public override func shouldBeSaved() -> Bool {
        return false
    }

    @objc
    public override var debugDescription: String {
        return "typingIndicatorMessage"
    }
}
