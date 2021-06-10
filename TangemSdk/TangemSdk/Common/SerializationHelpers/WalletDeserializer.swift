//
//  CardWalletDeserializer.swift
//  TangemSdk
//
//  Created by Andrew Son on 16/03/21.
//  Copyright © 2021 Tangem AG. All rights reserved.
//

import Foundation

class WalletDeserializer {
    func deserializeWallet(from decoder: TlvDecoder) throws -> Card.Wallet {
        let status: Card.Wallet.Status = try decoder.decode(.status)
        guard status == .loaded else { //We need only loaded wallets
            throw TangemSdkError.walletIsNotCreated
        }
        
        return try deserialize(from: decoder)
    }
    
    func deserializeWallets(from decoder: TlvDecoder) throws -> [Card.Wallet] {
        let cardWalletsData: [Data] = try decoder.decodeArray(.cardWallet)
        
        guard cardWalletsData.count > 0 else {
            throw TangemSdkError.deserializeApduFailed
        }
        
        let walletDecoders: [TlvDecoder] = cardWalletsData.compactMap {
            guard let infoTlvs = Tlv.deserialize($0) else { return nil }
            
            return TlvDecoder(tlv: infoTlvs)
        }
        
        let wallets: [Card.Wallet] = try walletDecoders.compactMap {
            do {
                return try deserializeWallet(from: $0)
            } catch TangemSdkError.walletIsNotCreated {
                return nil
            }
        }
        
        return wallets
    }
    
    private func deserialize(from decoder: TlvDecoder) throws -> Card.Wallet {
        let settings = Card.Wallet.Settings(mask: try decoder.decode(.settingsMask),
                                            signingMethods: try decoder.decode(.signingMethod))
        
        return Card.Wallet(publicKey: try decoder.decode(.walletPublicKey),
                   curve: try decoder.decode(.curveId),
                   settings: settings,
                   totalSignedHashes: try decoder.decode(.walletSignedHashes),
                   index: try decoder.decode(.walletIndex))
    }
}
