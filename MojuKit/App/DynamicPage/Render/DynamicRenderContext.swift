import UIKit

@MainActor
struct DynamicRenderContext {
    let dataStore: DynamicDataStore
    let templateResolver: DynamicTemplateResolver
    let styleParser: DynamicStyleParser
    let actionHandler: DynamicActionHandler
    let renderChildren: ([DynamicComponent], UIStackView, Int, DynamicTemplateResolver?) -> Void
    let registerImageTask: (Task<Void, Never>) -> Void
}
