//
//  Request.swift
//  Krypton
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON

final class Response:Jsonable {
    
    var requestID:String
    var snsEndpointARN:String
    var version:Version?
    var trackingID:String?
    
    var body:ResponseBody
    
    init(requestID:String, endpoint:String, body:ResponseBody, trackingID:String? = nil) {
        self.requestID = requestID
        self.snsEndpointARN = endpoint
        self.body = body
        self.trackingID = trackingID
        self.version = Properties.currentVersion
    }
    
    init(json: Object) throws {
        self.requestID = try json ~> "request_id"
        self.snsEndpointARN = try json ~> "sns_endpoint_arn"
        self.version = try Version(string: json ~> "v")
        self.body = try ResponseBody(json: json)
        
        if let trackingID:String = try? json ~> "tracking_id" {
            self.trackingID = trackingID
        }
    }
    
    var object:Object {
        var json = body.object
        json["request_id"] = requestID
        json["sns_endpoint_arn"] = snsEndpointARN
        
        if let trackingID = self.trackingID {
            json["tracking_id"] = trackingID
        }
        
        if let v = self.version {
            json["v"] = v.string
        }
        
        return json
    }
}

struct MultipleResponsesError:Error {}

enum ResponseBody {
    case me(ResponseResult<MeResponse>)
    
    case ssh(ResponseResult<SSHSignResponse>)
    case git(ResponseResult<GitSignResponse>)
    case ack(ResponseResult<AckResponse>)
    case unpair(ResponseResult<UnpairResponse>)
    case hosts(ResponseResult<HostsResponse>)
    
    // U2F
    case u2fRegister(ResponseResult<U2FRegisterResponse>)
    case u2fAuthenticate(ResponseResult<U2FAuthenticateResponse>)

    // team
    case readTeam(ResponseResult<SigChain.SignedMessage>)
    case teamOperation(ResponseResult<TeamOperationResponse>)
    case decryptLog(ResponseResult<LogDecryptionResponse>)

    init(json:Object) throws {
        
        var responses:[ResponseBody] = []
        
        // parse the requests
        if let json:Object = try? json ~> "me_response" {
            responses.append(.me(try ResponseResult<MeResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "sign_response" {
            responses.append(.ssh(try ResponseResult<SSHSignResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "git_sign_response" {
            responses.append(.git(try ResponseResult<GitSignResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "unpair_response" {
            responses.append(.unpair(try ResponseResult<UnpairResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "hosts_response" {
            responses.append(.hosts(try ResponseResult<HostsResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "ack_response" {
            responses.append(.ack(try ResponseResult<AckResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "read_team_response" {
            responses.append(.readTeam(try ResponseResult<SigChain.SignedMessage>(json: json)))
        }
        
        if let json:Object = try? json ~> "team_operation_response" {
            responses.append(.teamOperation(try ResponseResult<TeamOperationResponse>(json: json)))
        }

        if let json:Object = try? json ~> "log_decryption_response" {
            responses.append(.decryptLog(try ResponseResult<LogDecryptionResponse>(json: json)))
        }
        
        if let json:Object = try? json ~> "u2f_register_response" {
            responses.append(.u2fRegister(try ResponseResult<U2FRegisterResponse>(json: json)))
        }

        if let json:Object = try? json ~> "u2f_authenticate_response" {
            responses.append(.u2fAuthenticate(try ResponseResult<U2FAuthenticateResponse>(json: json)))
        }


        // if more than one response, it's an error
        if responses.count > 1 {
            throw MultipleResponsesError()
        }
        
        // set the request type
        self = responses[0]
    }
    
    var object:Object {
        var json = Object()
        
        switch self {
        case .me(let m):
            json["me_response"] = m.object
        case .ssh(let s):
            json["sign_response"] = s.object
        case .git(let g):
            json["git_sign_response"] = g.object
        case .ack(let a):
            json["ack_response"] = a.object
        case .unpair(let u):
            json["unpair_response"] = u.object
        case .hosts(let h):
            json["hosts_response"] = h.object
        case .readTeam(let r):
            json["read_team_response"] = r.object
        case .teamOperation(let op):
            json["team_operation_response"] = op.object
        case .decryptLog(let dl):
            json["log_decryption_response"] = dl.object
        case .u2fRegister(let r):
            json["u2f_register_response"] = r.object
        case .u2fAuthenticate(let a):
            json["u2f_authenticate_response"] = a.object
        }
        
        return json
    }
    
    var error:String? {
        switch self {
        case .ssh(let sign):
            return sign.error
            
        case .git(let gitSign):
            return gitSign.error
            
        case .hosts(let hosts):
            return hosts.error
                
        case .readTeam(let read):
            return read.error
            
        case .teamOperation(let teamOp):
            return teamOp.error
        
        case .decryptLog(let decryptLog):
            return decryptLog.error
            
        case .u2fRegister(let u2fRegister):
            return u2fRegister.error
            
        case .u2fAuthenticate(let u2fAuth):
            return u2fAuth.error
        
        case .me, .unpair, .ack:
            return nil
        }
    }
}

//MARK: Response Results
enum ResponseResult<T:Jsonable>:Jsonable {
    case ok(T)
    case error(String)
    
    init(json: Object) throws {
        if let err:String = try? json ~> "error" {
            self = .error(err)
            return
        }
        
        self = try .ok(T(json: json))
    }
    
    var object: Object {
        switch self {
        case .ok(let r):
            return r.object
        case .error(let err):
            return ["error": err]
        }
    }
    
    var error:String? {
        switch self {
        case .ok:
            return nil
        case .error(let e):
            return e
        }
    }
}


struct SignatureResponse:Jsonable {
    let signature:String

    init(signature:String) {
        self.signature = signature
    }
    
    init(json: Object) throws {
        try self.init(signature: json ~> "signature")
    }
    
    var object: Object {
        return ["signature": signature]
    }
}

struct EmptyResponse:Jsonable {
    init(){}
    init(json: Object) throws { }
    var object: Object {
        return [:]
    }
}

typealias SSHSignResponse = SignatureResponse
typealias GitSignResponse = SignatureResponse

// Me
struct MeResponse:Jsonable {
    struct Me {
        var email:String
        var publicKeyWire:Data
        var deviceIdentifier:U2FDeviceIdentifier
        var pgpPublicKey:Data?
        var teamCheckpoint:TeamCheckpoint?
        var u2fAccounts:[String]?
    }
    
    var me:Me
    
    init(me:Me) {
        self.me = me
    }
    init(json: Object) throws {
        self.me = try Me(json: json ~> "me")
    }
    var object: Object {
        return ["me": me.object]
    }
}

extension MeResponse.Me:Jsonable {
    init(json: Object) throws {
        self.email = try json ~> "email"
        self.publicKeyWire = try ((json ~> "public_key_wire") as String).fromBase64()
        self.deviceIdentifier = try ((json ~> "device_identifier") as String).fromBase64()
        self.pgpPublicKey = try? ((json ~> "pgp_pk") as String).fromBase64()
        self.teamCheckpoint = try? TeamCheckpoint(json: json ~> "team_checkpoint")
        self.u2fAccounts = try? json ~> "u2f_accounts"
    }
    
    var object: Object {
        var json : Object = ["email": email,
                             "public_key_wire": publicKeyWire.toBase64(),
                             "device_identifier": deviceIdentifier.toBase64()]
        
        if let pgpPublicKey = pgpPublicKey {
            json["pgp_pk"] = pgpPublicKey.toBase64()
        }
        if let teamCheckpoint = teamCheckpoint {
            json["team_checkpoint"] = teamCheckpoint.object
        }
        if let u2fAccounts = u2fAccounts {
            json["u2f_accounts"] = u2fAccounts
        }
        
        return json
    }
}

typealias UnpairResponse = EmptyResponse
typealias AckResponse = EmptyResponse

//HostsResponse
struct HostsResponse:Jsonable {
    
    struct UserAndHost:Jsonable, Equatable, Hashable {
        let host:String
        let user:String

        init(host:String, user:String) {
            self.host = host
            self.user = user
        }

        init(json: Object) throws {
            try self.init(host: json ~> "host",
                          user: json ~> "user")
        }

        var object: Object {
            return ["host": host, "user": user]
        }

        static func ==(l:UserAndHost, r:UserAndHost) -> Bool {
            return l.user == r.user && l.host == r.host
        }

        var hashValue: Int {
            return "\(user)@\(host)".hashValue
        }
    }
    
    struct HostInfo {
        let pgpUserIDs:[String]
        let hosts:[UserAndHost]
        
        init(pgpUserIDs:[String], hosts:[UserAndHost]) {
            self.pgpUserIDs = pgpUserIDs
            self.hosts = hosts
        }

        init(json: Object) throws {
            try self.init(pgpUserIDs: json ~> "pgp_user_ids",
                          hosts: [UserAndHost](json: json ~> "hosts"))
        }
        
        var object: Object {
            return ["pgp_user_ids": pgpUserIDs,
                    "hosts": hosts.objects]
        }
    }
    
    let hostInfo:HostInfo
    
    init(pgpUserIDs:[String], hosts:[UserAndHost]) {
        self.hostInfo = HostInfo(pgpUserIDs: pgpUserIDs, hosts: hosts)
    }

    init(json: Object) throws {
        self.hostInfo = try HostInfo(json: json ~> "host_info")
    }

    var object: Object {
        return ["host_info": hostInfo.object]
    }
}

// U2F
struct U2FRegisterResponse {
    let publicKey:Data
    let keyHandle:Data
    let attestationCertificate:Data
    let signature:Data
}

extension U2FRegisterResponse:Jsonable {
    init(json: Object) throws {
        self.publicKey = try ((try json ~> "public_key") as String).fromBase64()
        self.keyHandle = try ((try json ~> "key_handle") as String).fromBase64()
        self.attestationCertificate = try ((try json ~> "attestation_certificate") as String).fromBase64()
        self.signature = try ((try json ~> "signature") as String).fromBase64()
    }
    
    var object: Object {
        return [
            "public_key": publicKey.toBase64(),
            "key_handle": keyHandle.toBase64(),
            "attestation_certificate": attestationCertificate.toBase64(),
            "signature": signature.toBase64(),
        ]
    }
}

struct U2FAuthenticateResponse {
    let publicKey:Data
    let counter:Int32
    let signature:Data
}

extension U2FAuthenticateResponse:Jsonable {
    init(json: Object) throws {
        self.publicKey = try ((try json ~> "public_key") as String).fromBase64()
        self.counter = try json ~> "counter"
        self.signature = try ((try json ~> "signature") as String).fromBase64()
    }
    
    var object: Object {
        return [ "public_key": publicKey.toBase64(),
                 "counter": counter,
                 "signature": signature.toBase64()]
    }
}
