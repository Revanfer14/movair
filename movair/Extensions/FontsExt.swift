import SwiftUI

extension Font {
    enum Brand {
        // LargeTitle 34pt
        static let largeTitle           = Font.system(size: 34, weight: .regular)
        static let largeTitleBold       = Font.system(size: 34, weight: .bold)
        static let largeTitleItalic     = Font.system(size: 34, weight: .regular).italic()
 
        // Title2 22pt
        static let title2               = Font.system(size: 22, weight: .regular)
        static let title2Bold           = Font.system(size: 22, weight: .bold)
        static let title2Italic         = Font.system(size: 22, weight: .regular).italic()
 
        // Body 17pt
        static let body                 = Font.system(size: 17, weight: .regular)
        static let bodyBold             = Font.system(size: 17, weight: .bold)
        static let bodyItalic           = Font.system(size: 17, weight: .regular).italic()
 
        // Footnote 13pt
        static let footnote             = Font.system(size: 13, weight: .regular)
        static let footnoteBold         = Font.system(size: 13, weight: .bold)
        static let footnoteItalic       = Font.system(size: 13, weight: .regular).italic()
    }
}
