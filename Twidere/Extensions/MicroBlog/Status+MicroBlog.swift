//
//  Status+JSON.swift
//  Twidere
//
//  Created by Mariotaku Lee on 16/8/1.
//  Copyright © 2016年 Mariotaku Dev. All rights reserved.
//

import Foundation
import SwiftyJSON

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

fileprivate func <= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l <= r
    default:
        return !(rhs < lhs)
    }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}


extension Status {
    
    convenience init?(status: JSON, accountKey: UserKey?) {
        let id = getTwitterEntityId(status)
        let createdAt = parseTwitterDate(status["created_at"].stringValue)!
        let sortId = Status.generateSortId(rawId: status["raw_id"].int64 ?? -1, id: id, createdAt: createdAt)
        
        var primary = status["retweeted_status"]
        let retweet: JSON?
        if (primary.exists()) {
            retweet = status
        } else {
            primary = status
            retweet = nil
        }
        
        let user = primary["user"]
        let userKey = User.getUserKey(user, accountHost: accountKey?.host)
        let userName = user["name"].stringValue
        let userScreenName = user["screen_name"].stringValue
        let userProfileImage = Status.getProfileImage(user)
        
        let (textPlain, textDisplay, metadata) = Status.getMetadata(primary, accountKey: accountKey)
        
        metadata.replyCount = status["reply_count"].int64 ?? -1
        metadata.retweetCount = status["retweet_count"].int64 ?? -1
        metadata.favoriteCount = status["favorite_count"].int64 ?? -1
        
        self.init(accountKey: accountKey, sortId: sortId, createdAt: createdAt, id: id, userKey: userKey, userName: userName, userScreenName: userScreenName, userProfileImage: userProfileImage, textPlain: textPlain, textDisplay: textDisplay, metadata: metadata)
        
        if let retweet = retweet {
            self.retweetId = getTwitterEntityId(retweet)
            self.retweetCreatedAt = parseTwitterDate(retweet["created_at"].stringValue)!
            
            let retweetedBy = status["user"]
            let userId = getTwitterEntityId(retweetedBy)
            self.retweetedByUserKey = UserKey(id: userId, host: accountKey?.host)
            self.retweetedByUserName = retweetedBy["name"].string
            self.retweetedByUserScreenName = retweetedBy["screen_name"].string
            self.retweetedByUserProfileImage = Status.getProfileImage(retweetedBy)
        }
        
        let quoted = primary["quoted_status"]
        if (quoted.exists()) {
            self.quotedId = getTwitterEntityId(quoted)
            self.quotedCreatedAt = parseTwitterDate(quoted["created_at"].stringValue)!
            
            let quotedUser = quoted["user"]
            let quotedUserId = getTwitterEntityId(quotedUser)
            self.quotedUserKey = UserKey(id: quotedUserId, host: accountKey?.host)
            self.quotedUserName = quotedUser["name"].string
            self.quotedUserScreenName = quotedUser["screen_name"].string
            self.quotedUserProfileImage = Status.getProfileImage(quotedUser)
            
            let (quotedTextPlain, quotedTextDisplay, quotedMetadata) = Status.getMetadata(quoted, accountKey: accountKey)
            self.quotedTextPlain = quotedTextPlain
            self.quotedTextDisplay = quotedTextDisplay
            self.quotedMetadata = quotedMetadata
        }
        
    }
    
    static func arrayFromJson(_ json: JSON, accountKey: UserKey?) -> [Status] {
        if let array = json.array {
            return array.flatMap { item in return Status(status: item, accountKey: accountKey) }
        } else {
            return json["statuses"].flatMap { (key, item) in return Status(status: item, accountKey: accountKey) }
        }
    }
    
    fileprivate static func getProfileImage(_ user: JSON) -> String {
        return user["profile_image_url_https"].string ?? user["profile_image_url"].stringValue
    }
    
    fileprivate static let carets = CharacterSet(charactersIn: "<>")
    
    fileprivate static func getMetadata(_ status: JSON, accountKey: UserKey?) -> (plain: String, display: String, metadata: Status.Metadata) {

        if let statusNetHtml = status["statusnet_html"].string {
            let text = statusNetHtml.decodeHTMLEntitiesWithOffset()
            return (text, text, Status.Metadata())
        } else if let fullText = status["full_text"].string ?? status["text"].string {
            return getTwitterStatusMetadata(status, fullText: fullText, accountKey: accountKey)
        } else {
            let text = status["text"].stringValue
            return (text, text, Status.Metadata())
        }
        
    }
    
    fileprivate static func getTwitterStatusMetadata(_ status: JSON, fullText:String, accountKey: UserKey?) -> (plain: String, display: String, metadata: Status.Metadata) {
        
        var links = [LinkSpanItem]()
        var mentions = [MentionSpanItem]()
        var hashtags = [HashtagSpanItem]()
        
        let (spans, mediaItems) = getMediaSpans(status: status, accountKey: accountKey)
        var codePointOffset = 0
        var codePoints = fullText.unicodeScalars
        
        // Display text range in utf16
        var displayTextRangeCodePoint: [Int]? = nil
        var displayTextRangeUtf16: [Int]? = nil
        
        if let displayStart = status["display_text_range"][0].int, let displayEnd = status["display_text_range"][1].int {
            displayTextRangeCodePoint = [displayStart, displayEnd]
            displayTextRangeUtf16 = [
                codePoints.utf16Count(codePoints.startIndex..<codePoints.index(codePoints.startIndex, offsetBy: displayStart)),
                codePoints.utf16Count(codePoints.startIndex..<codePoints.index(codePoints.startIndex, offsetBy: displayEnd))
            ]
        }
        
        for span in spans {
            let origStart = span.origStart, origEnd = span.origEnd
            
            let offsetedStart = origStart + codePointOffset
            let offsetedEnd = origEnd + codePointOffset
            
            var startIndex = codePoints.startIndex
            
            switch span {
            case let typed as LinkSpanItem:
                let displayUrlCodePoints = typed.display!.unicodeScalars
                let displayCodePointsLength = displayUrlCodePoints.count
                let displayUtf16Length = typed.display!.utf16.count
                
                let subRange = codePoints.index(codePoints.startIndex, offsetBy: offsetedStart)..<codePoints.index(codePoints.startIndex, offsetBy: offsetedEnd)
                
                let subRangeUtf16Length = codePoints.utf16Count(subRange)
                
                codePoints.replaceSubrange(subRange, with: displayUrlCodePoints)
                
                startIndex = codePoints.startIndex
                
                typed.start = codePoints.utf16Count(startIndex..<codePoints.index(codePoints.startIndex, offsetBy: offsetedStart))
                typed.end = typed.start + displayUtf16Length
                links.append(typed)
                
                let codePointDiff = displayCodePointsLength - (origEnd - origStart)
                let utf16Diff = displayUtf16Length - subRangeUtf16Length
                codePointOffset += codePointDiff
                if (typed.origEnd < displayTextRangeCodePoint?[0]) {
                    displayTextRangeUtf16?[0] += utf16Diff
                }
                if (typed.origEnd <= displayTextRangeCodePoint?[1]) {
                    displayTextRangeUtf16?[1] += utf16Diff
                }
            case let typed as MentionSpanItem:
                typed.start = codePoints.utf16Count(startIndex..<codePoints.index(codePoints.startIndex, offsetBy: offsetedStart))
                typed.end = typed.start + origEnd - origStart
                mentions.append(typed)
            case let typed as HashtagSpanItem:
                typed.start = codePoints.utf16Count(startIndex..<codePoints.index(codePoints.startIndex, offsetBy: offsetedStart))
                typed.end = typed.start + origEnd - origStart
                hashtags.append(typed)
            default: abort()
            }
            
        }
        
        let str = String(codePoints)
        let textDisplay = str.decodeHTMLEntitiesWithOffset { (index, utf16Offset) in
            let intIndex = str.distance(from: str.startIndex, to: index)
            
            for var span in spans where span.origStart >= intIndex {
                span.start += utf16Offset
                span.end += utf16Offset
            }
            if (displayTextRangeUtf16 != nil) {
                if (displayTextRangeUtf16![0] >= intIndex) {
                    displayTextRangeUtf16![0] += utf16Offset
                }
                if (displayTextRangeUtf16![1] >= intIndex) {
                    displayTextRangeUtf16![1] += utf16Offset
                }
            }
        }
        let textPlain = fullText.decodeHTMLEntitiesWithOffset()
        
        let inReplyTo = Status.Metadata.InReplyTo(status: status, accountKey: accountKey)
        inReplyTo?.completeUserName(mentions)
        
        let externalUrl = status["external_url"].string
        let metadata = Status.Metadata(links: links, mentions: mentions, hashtags: hashtags, media: mediaItems, displayRange: displayTextRangeUtf16, inReplyTo: inReplyTo, externalUrl: externalUrl, replyCount: -1, retweetCount: -1, favoriteCount: -1)
        
        return (textPlain, textDisplay, metadata)
    }
    
    fileprivate static func findByOrigRange(_ spans: [SpanItem], start: Int, end:Int)-> [SpanItem] {
        var result = [SpanItem]()
        for span in spans {
            if (span.origStart >= start && span.origEnd <= end) {
                result.append(span)
            }
        }
        return result
    }
    
    fileprivate static func getMediaSpans(status: JSON, accountKey: UserKey?) -> ([SpanItem], [MediaItem]) {
        var spans: [SpanItem] = []
        var mediaItems: [MediaItem] = []
        for (_, entity) in status["entities"]["urls"] {
            spans.append(LinkSpanItem(from: entity))
        }
        
        for (_, entity) in status["entities"]["user_mentions"] {
            spans.append(MentionSpanItem(from: entity, accountKey: accountKey))
        }
        
        for (_, entity) in status["entities"]["hashtags"] {
            spans.append(HashtagSpanItem(from: entity))
        }
        
        if let extendedMedia = status["extended_entities"]["media"].array {
            for entity in extendedMedia {
                spans.append(LinkSpanItem(from: entity))
                mediaItems.append(MediaItem(from: entity))
            }
        } else if let media = status["entities"]["media"].array {
            for entity in media {
                spans.append(LinkSpanItem(from: entity))
                mediaItems.append(MediaItem(from: entity))
            }
        }
        
        var indices = [Range<Int>]()
        
        // Remove duplicate entities
        spans = spans.filter { entity -> Bool in
            if (entity.origStart < 0 || entity.origEnd < 0) {
                return false
            }
            let range: Range<Int> = entity.origStart..<entity.origEnd
            if (hasClash(sortedIndices: indices, range: range)) {
                return false
            }
            //
            if let insertIdx = indices.index(where: { item -> Bool in return item.lowerBound > range.lowerBound }) {
                indices.insert(range, at: insertIdx)
            } else {
                indices.append(range)
            }
            return true
        }
        
        // Order entities
        spans.sort { (l, r) -> Bool in
            return l.origStart < r.origEnd
        }
        return (spans, mediaItems)
    }
    
    fileprivate static func hasClash(sortedIndices: [Range<Int>], range: Range<Int>) -> Bool {
        if (range.upperBound < sortedIndices.first?.lowerBound) {
            return false
        }
        if (range.lowerBound > sortedIndices.last?.upperBound) {
            return false
        }
        var i = 0
        while i < sortedIndices.endIndex - 1 {
            let end = sortedIndices[i].upperBound
            let start = sortedIndices[i + 1].lowerBound
            if (range.lowerBound > end && range.upperBound < start) {
                return false
            }
            i += 1
        }
        return true
    }
    
    internal static func generateSortId(rawId: Int64, id: String, createdAt: Date) -> Int64 {
        var sortId = rawId
        if (sortId == -1) {
            // Try use long id
            sortId = Int64(id) ?? -1
        }
        if (sortId == -1) {
            // Try use timestamp
            sortId = createdAt.timeIntervalSince1970Millis
        }
        return sortId
    }
    
    fileprivate enum EntityType {
        case mention, url, hashtag
    }
    
    class Spans {
        
        var links: [LinkSpanItem]?
        var mentions: [MentionSpanItem]?
        var hashtags: [HashtagSpanItem]?
    }
}

extension MediaItem {
    
    convenience init(from entity: JSON) {
        let url = entity["media_url_https"].string ?? entity["media_url"].stringValue
        let pageUrl = entity["expanded_url"].string
        let type = MediaItem.getMediaType(entity["type"].string)
        let altText = entity["alt_text"].string
        let width = entity["sizes"]["large"]["w"].intValue
        let height = entity["sizes"]["large"]["h"].intValue
        let videoInfo = MediaItem.VideoInfo(from: entity["video_info"])
        self.init(url: url, mediaUrl: url, previewUrl: url, type: type, width: width, height: height, videoInfo: videoInfo, pageUrl: pageUrl, altText: altText)
    }
    
    fileprivate static func getMediaType(_ type: String?) -> MediaItem.MediaType {
        switch type {
        case "photo"?:
            return .image
        case "video"?:
            return .video
        case "animated_gif"?:
            return .animatedGif
        default: break
        }
        return .unknown
    }
}

extension MediaItem.VideoInfo {
    
    convenience init(from videoInfo: JSON) {
        let duration = videoInfo["duration"].int64Value
        let variants = videoInfo["variants"].flatMap { (k, v) -> MediaItem.VideoInfo.Variant? in
            guard let url = v["url"].string else {
                return nil
            }
            let contentType = v["content_type"].string
            let bitrate = v["bitrate"].int64Value
            
            return MediaItem.VideoInfo.Variant(url: url, contentType: contentType, bitrate: bitrate)
        }
        self.init(variants: variants, duration: duration)
    }
}

extension LinkSpanItem {
    
    convenience init(from entity: JSON) {
        let origStart = entity["indices"][0].int ?? -1
        let origEnd = entity["indices"][1].int ?? -1
        let link = entity["expanded_url"].stringValue
        let display = entity["display_url"].string
        self.init(origStart: origStart, origEnd: origEnd, link: link, display: display)
    }
    
}

extension MentionSpanItem {
    
    convenience init(from entity: JSON, accountKey: UserKey?) {
        let id = entity["id_str"].string ?? entity["id"].stringValue
        
        let origStart = entity["indices"][0].int ?? -1
        let origEnd = entity["indices"][1].int ?? -1
        
        let key = UserKey(id: id, host: accountKey?.host)
        let name = entity["name"].string
        let screenName = entity["screen_name"].stringValue
        self.init(origStart: origStart, origEnd: origEnd, key: key, name: name, screenName: screenName)
    }
}

extension HashtagSpanItem {
    
    convenience init(from entity: JSON) {
        let origStart = entity["indices"][0].int ?? -1
        let origEnd = entity["indices"][1].int ?? -1
        
        let hashtag = entity["text"].stringValue
        self.init(origStart: origStart, origEnd: origEnd, hashtag: hashtag)
    }
    
}

extension Status.Metadata.InReplyTo {
    convenience init?(status: JSON, accountKey: UserKey?) {
        guard let statusId = status["in_reply_to_status_id"].string, let userId = status["in_reply_to_user_id"].string, !statusId.isEmpty && !userId.isEmpty else {
            return nil
        }
        let userKey = UserKey(id: userId, host: accountKey?.host)
        let userScreenName = status["in_reply_to_screen_name"].stringValue
        self.init(statusId: statusId, userKey: userKey, userScreenName: userScreenName)
    }
    
    func completeUserName(_ mentions: [MentionSpanItem]) {
        self.userName = mentions.filter { $0.key.id == self.userKey.id }.first?.name
    }
}
