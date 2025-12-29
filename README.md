# elm-initialization
This package helps you separate the setup process (the initializing phase)
of your application from the main loop (the running phase),
allowing you to express that the set of available data differs between these two phases.

## Problems This Package Solves
The following example generates a random dice roll and is taken from the official Elm guide.
```elm
import Browser
import Html exposing (..)
import Html.Events exposing (..)
import Random



-- MAIN


main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }



-- MODEL


type alias Model =
  { dieFace : Int
  }


init : () -> (Model, Cmd Msg)
init _ =
  ( Model 1
  , Cmd.none
  )



-- UPDATE


type Msg
  = Roll
  | NewFace Int


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Roll ->
      ( model
      , Random.generate NewFace (Random.int 1 6)
      )

    NewFace newFace ->
      ( Model newFace
      , Cmd.none
      )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none



-- VIEW


view : Model -> Html Msg
view model =
  div []
    [ h1 [] [ text (String.fromInt model.dieFace) ]
    , button [ onClick Roll ] [ text "Roll" ]
    ]
```
In this example, the initial dice face is set to `1`.

In real applications, this can be misleading: users may assume that the initially displayed value was randomly generated, even though no randomness has occurred yet.

A common workaround is to change the type of dieFace in `Model` from `Int` to `Maybe Int`. While this correctly represents the absence of a value during initialization, it also propagates uncertainty throughout the application, requiring repeated wrapping and unwrapping even after initialization has completed.

## The Solution This Package Provides 
This package makes the initialization phase explicit by introducing a separate `InitializingModel`, which represents data that is still being prepared before the main application loop starts.

Using this approach, the example above can be rewritten as follows:
```elm

import Html exposing (..)
import Html.Events exposing (..)
import Initialization -- You don't have to call Browser.element directly
import Random
import Result



-- MAIN


type alias Flag =
    ()


type alias InitializingModel =
    { mDieFace : Maybe Int }


type alias BlockingReason = String

main : Initialization.Program Flag InitializingModel Model Msg -- Note: the InitializingModel type must be specified.
main =
    let
        toRunning : InitializingModel -> Result (List BlockingReason) ( Model, Cmd Msg )
        toRunning { mDieFace } =
            case mDieFace of
                Nothing ->
                    Err [ "Random die face is not yet generated." ]

                Just n ->
                    Ok ( Model n, Cmd.none )

        initView : List BlockingReason -> InitializingModel -> Html (InitializingModel -> InitializingModel)
        initView blockingReasons initializingModel =
            List.map text blockingReasons
                |> List.intersperse (br [] [])
                |> div []

        init : Flag -> (InitializingModel, Cmd (InitializingModel -> InitializingModel))
        init flag =
            ( InitializingModel Nothing
            , Random.generate
                (\n iModel -> { iModel | mDieFace = Just n })
                (Random.int 1 6)
            )

    in
    Initialization.element
        { init = init
        , initView = initView
        , toRunning = toRunning
        }
        { update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Model =
    { dieFace : Int
    }



-- UPDATE


type Msg
    = Roll
    | NewFace Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Roll ->
            ( model
            , Random.generate NewFace (Random.int 1 6)
            )

        NewFace newFace ->
            ( Model newFace
            , Cmd.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text (String.fromInt model.dieFace) ]
        , button [ onClick Roll ] [ text "Roll" ]
        ]
```
Here, `BlockingReason` is defined as a type alias for `String`,
which is sufficient for simple use cases.
More structured representations are possible by using a custom type.

Once the `InitializingModel` has gained enough information, it is converted by the function assigned to the `toRunning` into the main-loop `Model`, and the application proceeds as a regular Elm program.

## How `Initialization.element` Works
You define an `InitializingModel` that represents the intermediate state before initialization completes.

Each field of the first argument of `Initialization.element` has the following role:

- `toRunning : initializingModel -> Result (List blockingReason) ( runningModel, Cmd runningMsg)` :
    - Called whenever the `initializingModel` is updated.
    - Attempts to convert the current `initializingModel` into the main-loop `runningModel`.
        - On success, returns `Ok ( runningModel, Cmd runningMsg )`, and the main loop begins, similar to the init function of a standard Elm application by `Browser.element`.
        - On failure, returns `Err (List blockingReason)`, where `blockingReason` is a user-defined type describing why initialization cannot proceed yet.
        - ⚠️ When `Ok _` is returned, the initializing phase is immediately terminated and all remaining `Cmd` results arriving after the phase change are ignored. Be careful not to return `Ok _` before data required for your app such as HTTP responses arrives.
- `init : flag -> ( initializingModel, Cmd (initializingModel -> initializingModel))` :
    - At the very first of the initialization phase, returns the `initializingModel` and a command that is needed to make the initializing model convertible to the `Model` of main-loop.
- `initView : List BlockingReason -> Html (InitializingModel -> InitializingModel)` :
    - A view function that is used before the main loop begins.
    - The returned `Html` may emit messages that update the initializing model.


> ℹ️ Debugging the initialization phase  
>
> When compiled with the `--debug` flag, Elm’s debugger provides only limited insight
> into what is happening during the initialization phase.
>
> If you want to observe *when* and *why* initialization is blocked,
> or inspect intermediate model transformations in more detail,
> see the `Initialization.Debuggable` module.
> It provides the same semantics as `Initialization.element`,
> with additional hooks for attaching descriptions and debug information.

## Limitations
The `Initialization` module is intentionally limited in scope.

During the initialization phase it manages, new commands cannot be added dynamically. As a result, it is not suitable for initialization flows that depend on user interaction or on the results of earlier commands.

If you need that level of flexibility, consider using `Initialization.Advanced`, or modeling initialization explicitly in your application state. For example:
```elm
type Model
    = Initializing InitializingModel
    | Running RunningModel

type Msg
    = InitializingMsg InitializingMsg
    | RunningMsg RunningMsg
```

