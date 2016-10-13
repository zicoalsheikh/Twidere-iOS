// Automatically generated, DO NOT MODIFY
import Freddy
import Foundation

extension User: JSONEncodable, JSONDecodable {

    init(json value: JSON) throws {
        self._id = nil
        self.accountKey = try? value.decode(at: "account_key")
        self.key = try? value.decode(at: "user_key")
        self.createdAt = try? value.decode(at: "created_at")
        self.position = nil
        self.isProtected = try? value.decode(at: "is_protected")
        self.isVerified = try? value.decode(at: "is_verified")
        self.name = try? value.decode(at: "name")
        self.screenName = try? value.decode(at: "screen_name")
        self.profileImageUrl = try? value.decode(at: "profile_image_url")
        self.profileBannerUrl = try? value.decode(at: "profile_banner_url")
        self.profileBackgroundUrl = try? value.decode(at: "profile_background_url")
        self.descriptionPlain = try? value.decode(at: "description_plain")
        self.descriptionDisplay = try? value.decode(at: "description_display")
        self.url = try? value.decode(at: "url")
        self.urlExpanded = try? value.decode(at: "url_expanded")
        self.location = try? value.decode(at: "location")
        self.metadata = try? value.decode(at: "metadata")
    }

    public func toJSON() -> JSON {
        var dict: [String: JSON] = [

        ]
        return .dictionary(dict)
    }
}

extension User.Metadata: JSONEncodable, JSONDecodable {

    init(json value: JSON) throws {
        self.following = try? value.decode(at: "following")
        self.followedBy = try? value.decode(at: "followed_by")
        self.blocking = try? value.decode(at: "blocking")
        self.blockedBy = try? value.decode(at: "blocked_by")
        self.muting = try? value.decode(at: "muting")
        self.followRequestSent = try? value.decode(at: "follow_request_sent")
        self.descriptionLinks = try? value.getArray(at: "description_links").map(LinkSpanItem.init)
        self.descriptionMentions = try? value.getArray(at: "description_mentions").map(MentionSpanItem.init)
        self.descriptionHashtags = try? value.getArray(at: "description_hashtags").map(HashtagSpanItem.init)
        self.linkColor = try? value.decode(at: "link_color")
        self.backgroundColor = try? value.decode(at: "background_color")
        self.statusesCount = try? value.decode(at: "statuses_count")
        self.followersCount = try? value.decode(at: "followers_count")
        self.friendsCount = try? value.decode(at: "friends_count")
        self.favoritesCount = try? value.decode(at: "favorites_count")
        self.mediaCount = try? value.decode(at: "media_count")
        self.listsCount = try? value.decode(at: "lists_count")
        self.listedCount = try? value.decode(at: "listed_count")
        self.groupsCount = try? value.decode(at: "groups_count")
    }

    public func toJSON() -> JSON {
        var dict: [String: JSON] = [

        ]
        return .dictionary(dict)
    }
}

