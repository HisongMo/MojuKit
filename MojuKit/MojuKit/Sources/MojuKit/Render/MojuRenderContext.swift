import UIKit

@MainActor
struct MojuRenderContext {
    let dataStore: MojuDataStore
    let templateResolver: MojuTemplateResolver
    let styleParser: MojuStyleParser
    let actionHandler: MojuActionHandler
    let imageProvider: MojuImageProviding
    let renderChildren: ([MojuComponent], UIStackView, Int, MojuTemplateResolver?) -> Void
    let registerImageTask: (Task<Void, Never>) -> Void
}
