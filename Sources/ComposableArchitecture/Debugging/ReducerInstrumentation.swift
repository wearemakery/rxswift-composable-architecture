import RxSwift
import os.signpost

extension Reducer {
  /// Instruments the reducer with
  /// [signposts](https://developer.apple.com/documentation/os/logging/recording_performance_data).
  /// Each invocation of the reducer will be measured by an interval, and the lifecycle of its
  /// effects will be measured with interval and event signposts.
  ///
  /// To use, build your app for Instruments (⌘I), create a blank instrument, and then use the "+"
  /// icon at top right to add the signpost instrument. Start recording your app (red button at top
  /// left) and then you should see timing information for every action sent to the store and every
  /// effect executed.
  ///
  /// Effect instrumentation can be particularly useful for inspecting the lifecycle of long-living
  /// effects. For example, if you start an effect (e.g. a location manager) in `onAppear` and
  /// forget to tear down the effect in `onDisappear`, it will clearly show in Instruments that the
  /// effect never completed.
  ///
  /// - Parameters:
  ///   - prefix: A string to print at the beginning of the formatted message for the signpost.
  ///   - log: An `OSLog` to use for signposts.
  /// - Returns: A reducer that has been enhanced with instrumentation.
  public func signpost(
    _ prefix: String = "",
    log: OSLog = OSLog(
      subsystem: "co.pointfree.composable-architecture",
      category: "Reducer Instrumentation"
    )
  ) -> Self {
    // NB: Prevent rendering as "N/A" in Instruments
    let zeroWidthSpace = "\u{200B}"

    let prefix = prefix.isEmpty ? zeroWidthSpace : "[\(prefix)] "

    return Self { state, action, environment in
      var actionOutput: String!
        actionOutput = debugCaseOutput(action)
        os_log("Action %s%s", prefix, actionOutput)
      let effects = self.run(&state, action, environment)
        return
          effects
          .effectSignpost(prefix, log: log, actionOutput: actionOutput)
          .eraseToEffect()
    }
  }
}

extension ObservableType {
  func effectSignpost(
    _ prefix: String,
    log: OSLog,
    actionOutput: String
  ) -> Observable<Element> {

    return
      self
      .do(
        onNext: { _ in
            os_log("Effect Output: %sOutput from %s", prefix, actionOutput)
        },
        onCompleted: {
            os_log("Effect %sFinished", prefix)
        },
        onSubscribe: {
            os_log("Effect %sStarted from %s", prefix)
        },
        onDispose: {
            os_log("Effect %sCancelled", prefix)
        }
      )
  }
}

func debugCaseOutput(_ value: Any) -> String {
  let mirror = Mirror(reflecting: value)
  switch mirror.displayStyle {
  case .enum:
    guard let child = mirror.children.first else {
      let childOutput = "\(value)"
      return childOutput == "\(type(of: value))" ? "" : ".\(childOutput)"
    }
    let childOutput = debugCaseOutput(child.value)
    return ".\(child.label ?? "")\(childOutput.isEmpty ? "" : "(\(childOutput))")"
  case .tuple:
    return mirror.children.map { label, value in
      let childOutput = debugCaseOutput(value)
      return "\(label.map { "\($0):" } ?? "")\(childOutput.isEmpty ? "" : " \(childOutput)")"
    }
    .joined(separator: ", ")
  default:
    return ""
  }
}
