//
//  WriteBackupDataCommand.swift
//  TangemSdk
//
//  Created by Alexander Osokin on 24.08.2021.
//  Copyright © 2021 Tangem AG. All rights reserved.
//

import Foundation

// Response from the Tangem card after `WriteBackupDataCommand`.
@available(iOS 13.0, *)
struct WriteBackupDataResponse {
    /// Unique Tangem card ID number
    let cardId: String
    let backupStatus: Card.BackupRawStatus
}

@available(iOS 13.0, *)
final class WriteBackupDataCommand: Command {
    var requiresPasscode: Bool { return false }
    
    private let backupData: EncryptedBackupData
    private let accessCode: Data
    private let passcode: Data
    
    init(backupData: EncryptedBackupData, accessCode: Data, passcode: Data) {
        self.backupData = backupData
        self.accessCode = accessCode
        self.passcode = passcode
    }
    
    deinit {
        Log.debug("WriteBackupDataCommand deinit")
    }
    
    func performPreCheck(_ card: Card) -> TangemSdkError? {
        if card.firmwareVersion < .backupAvailable {
            return .notSupportedFirmwareVersion
        }
        
        if !card.settings.isBackupAllowed {
            return .backupCannotBeCreated
        }
        
        if card.backupStatus == .noBackup {
            return .backupCannotBeCreated
        }
        
        if !card.wallets.isEmpty {
            return .backupCannotBeCreatedNotEmptyWallets
        }

        return nil
    }
    
    func run(in session: CardSession, completion: @escaping CompletionResult<WriteBackupDataResponse>) {
        transceive(in: session) { result in
            switch result {
            case .success(let response):
                if case let .cardLinked(cardsCount: cardsCount) = session.environment.card?.backupStatus {
                    session.environment.card?.backupStatus = try? Card.BackupStatus(from: response.backupStatus, cardsCount: cardsCount)
                }
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func serialize(with environment: SessionEnvironment) throws -> CommandApdu {
        let tlvBuilder = try createTlvBuilder(legacyMode: environment.legacyMode)
            .append(.cardId, value: environment.card?.cardId)
            .append(.pin, value: accessCode)
            .append(.pin2, value: passcode)
            .append(.salt, value: backupData.salt)
            .append(.issuerData, value: backupData.data)
        
        return CommandApdu(.writeBackupData, tlv: tlvBuilder.serialize())
    }
    
    func deserialize(with environment: SessionEnvironment, from apdu: ResponseApdu) throws -> WriteBackupDataResponse {
        guard let tlv = apdu.getTlvData(encryptionKey: environment.encryptionKey) else {
            throw TangemSdkError.deserializeApduFailed
        }
        
        let decoder = TlvDecoder(tlv: tlv)
        
        return WriteBackupDataResponse(cardId: try decoder.decode(.cardId),
                                       backupStatus: try decoder.decode(.backupStatus))
    }
}

