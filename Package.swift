// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MBProgressHUD",
    products: [
        .library(name: "MBProgressHUD", targets: ["MBProgressHUD"])
    ],
    targets: [
        .target(
            name: "MBProgressHUD",
            dependencies: [],
            path: ".",
            exclude: ["Demo"],
            sources: ["MBProgressHUD.h", "MBProgressHUD.m"],
            resources: [.copy("PrivacyInfo.xcprivacy")],
            publicHeadersPath: "include",
            cSettings: [
                .define("NS_BLOCK_ASSERTIONS", to: "1", .when(configuration: .release))
            ]
        )
    ]
)
