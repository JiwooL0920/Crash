import GraphicSVG exposing (..)
import GraphicSVG.App exposing (..)
import Browser
import Browser.Navigation exposing (Key(..))
import GraphicSVG exposing (..)
import GraphicSVG.App exposing (..)
import Url
import Random
import List exposing(..)
import Tuple exposing(..)
import String exposing(..)
import Json.Encode as JEncode
import Json.Decode as JDecode
import Html exposing (..)
import Html.Attributes
import Html.Events as Events
import Http
import Debug

--<<Type Declaration>>
type Msg = Tick Float GetKeyState
         | MakeRequest Browser.UrlRequest
         | UrlChange Url.Url
         | DecideBigPlayer Player
         | ChangeColorTheme ThemeButton
         | LoginPost
         | SignUpPost
         | LogoutPost
         | GotoSignUpScreen
         | GotoLeaderBoardScreen
         | GoBackToGame
         | GoBack
         | GotLoginResponse (Result Http.Error String) 
         | GotSignupResponse (Result Http.Error String) 
         | GotLogoutResponse (Result Http.Error String) 
         | Username String
         | Password String
         | PostUserInfo (Result Http.Error String) 
         | GetUserInfo (Result Http.Error UserInfo)
         | GetLeaderBoard (Result Http.Error Ranking)


type Player = Player1 | Player2 | None

type State = Jump | NotJump

type GameStatus = Start | InProgress | End

type Screen = Login | SignUp | Game GameStatus | LeaderBoard

type ColorTheme = Theme1 | Theme2 | Theme3 | Theme4 | Theme5 

type ThemeButton = ThemeUp | ThemeDown | ThemeRight | ThemeLeft

type alias Model = { screen : Screen
                   , error : String 
                   , player1_pos : (Float,Float)
                   , player2_pos : (Float, Float)
                   , count : Int
                   , jumpX : Float
                   , bigPlayer : Player
                   , jumpingPlayer : Player
                   , gameEnd : Bool
                   , credentials : Credentials
                   , userinfo : UserInfo       
                   , leaderBoard : Ranking
                   , points : Int
                   } 

--Need for server
type alias Credentials = { username : String
                         , password : String
                         }

type alias Highscore = { username : String
                       , highscore : Int
                       }

type alias Ranking = { firstPlace : Highscore
                     , secondPlace : Highscore 
                     , thirdPlace : Highscore 
                     , fourthPlace : Highscore 
                     , fifthPlace : Highscore
                     }

type alias UserInfo = { highscore : Int
                      , avgPoints : Float
                      , gamesPlayed : Int
                      , playerTheme : ColorTheme 
                      , deviceTheme : ColorTheme
                      }

--<<Helper Functions>>-------------------------------------------------------------------------------------------------------------------------------------------------------------
--Function to get the jumping motion
getProjectile : Float -> Player -> Player -> Float 
getProjectile x bigPlayer jumpingPlayer = 
    let angle = 1.2
        g = if bigPlayer == jumpingPlayer then 0.49 else 0.8
        v = 4
        blob = g/(2*(v^2)*(cos(angle))^2)
    in (tan(angle)*x) - blob*(x^2)

--Function to update the player's position
updatePos : (Float,Float) -> (Float,Float) -> (Float,Float)
updatePos (a,b) (c,d) = (a+c,d)

--COLLISION DETECTION
--Check if a jumping big player collides with the small player
isCollisionBigOnSmall : (Float,Float) -> (Float,Float) -> Bool 
isCollisionBigOnSmall (a,b) (c,d) = 
    if a+16 > c  && abs(b-d) <= 9.5 && c > -6 then True 
    else False 

--Check if a jumping small player collides with the big player
isCollisionSmallOnBig : (Float,Float) -> (Float,Float) -> Bool 
isCollisionSmallOnBig (a,b) (c,d) =     
    if a+16 > c && (abs(b-d) < 17 && c > -6) then True 
    else False 

--Check if there's a x-collusion only (no jumping movement)
isCollisionNoJump : (Float,Float) -> (Float,Float) -> Bool 
isCollisionNoJump (a,b) (c,d) = a+16 >c  && c > -6

--Helper function to tell if both bigPlayer and jumpingPlayer are the same
playerMatch : Player -> Player -> Bool 
playerMatch a b = 
    if List.all (\x->x==Player1) [a,b] || List.all (\x->x==Player2) [a,b] then True 
    else False 

--Final collision function
isCollision : Model -> Bool 
isCollision model = 
    if playerMatch model.bigPlayer model.jumpingPlayer then
        isCollisionBigOnSmall model.player1_pos model.player2_pos 
    else if playerMatch model.bigPlayer model.jumpingPlayer == False then 
        isCollisionSmallOnBig model.player1_pos model.player2_pos 
    else isCollisionNoJump model.player1_pos model.player2_pos 

--Function to decide which player is bigger
randomizeSize : Random.Generator Player
randomizeSize = Random.map (\b -> if b == 0 then Player1 else Player2) <| Random.int 0 1

randDecideSize : Cmd Msg  
randDecideSize = Random.generate DecideBigPlayer randomizeSize

--Change Themes
changeThemeRight : ColorTheme -> ColorTheme 
changeThemeRight colorTheme =
        case colorTheme of 
                Theme1 -> Theme2
                Theme2 -> Theme3
                Theme3 -> Theme4
                Theme4 -> Theme5
                Theme5 -> Theme1

changeThemeLeft : ColorTheme -> ColorTheme 
changeThemeLeft colorTheme = 
        case colorTheme of 
                Theme5 -> Theme4 
                Theme4 -> Theme3
                Theme3 -> Theme2
                Theme2 -> Theme1
                Theme1 -> Theme5

colorThemeToPlayerColor : ColorTheme -> (Color, Color)
colorThemeToPlayerColor colorTheme = 
        case colorTheme of 
                Theme1 -> (red, blue)
                Theme2 -> (rgb 209 68 86, rgb 169 252 136)
                Theme3 -> (rgb 230 25 75, rgb 223 220 234)
                Theme4 -> (rgb 227 52 82, rgb 215 243 110)
                Theme5 -> (rgb 41 96 45, rgb 255 225 89)

colorThemeToDeviceColor : ColorTheme -> (Color, Color)
colorThemeToDeviceColor colorTheme =   
        case colorTheme of 
            Theme1 -> (rgb 42 54 82, rgb 211 224 247)
            Theme2 -> (rgb 215 243 110, rgb 227 52 82)
            Theme3 -> (rgb 38 54 98, rgb 156 213 190)
            Theme4 ->  (rgb 230 25 75, rgb 223 220 234)
            Theme5 -> (rgb 73 105 72, rgb 229 232 151)

colorThemeToString : ColorTheme -> String
colorThemeToString colorTheme = 
        case colorTheme of 
                Theme1 -> "1"
                Theme2 -> "2"
                Theme3 -> "3"
                Theme4 -> "4" 
                Theme5 -> "5"

--textOutline (to avoid repetition)
textOutline : String -> Float -> Shape userMsg
textOutline string n = GraphicSVG.text (string) |> bold |> sansserif |> size n |> filled black 



--SERVER------------------------
rootUrl = "https://mac1xa3.ca/e/leej229/"

--User Authentication
userPassEncoder : Model -> JEncode.Value
userPassEncoder model =
    JEncode.object
        [ ( "username", JEncode.string model.credentials.username)
        , ( "password", JEncode.string model.credentials.password)
        ]

loginPost : Model -> Cmd Msg
loginPost model =
    Http.post
        { url = rootUrl ++ "loginuser/"
        , body = Http.jsonBody <| userPassEncoder model 
        , expect = Http.expectString GotLoginResponse
        }

logoutPost : Cmd Msg 
logoutPost =
    Http.get 
        { url = rootUrl ++ "logoutuser/"
        , expect = Http.expectString GotLogoutResponse
        }

signupPost : Model -> Cmd Msg
signupPost model =
    Http.post
        { url = rootUrl ++ "signup/"
        , body = Http.jsonBody <| userPassEncoder model
        , expect = Http.expectString GotSignupResponse
        }

--UserInfo
userInfoEncoder : Model -> JEncode.Value 
userInfoEncoder model =
    JEncode.object
        [  ("highscore", JEncode.int model.userinfo.highscore)
          , ("points", JEncode.int model.points)
          , ("gamesPlayed", JEncode.int model.userinfo.gamesPlayed)
          , ("playerTheme", JEncode.string (colorThemeToString model.userinfo.playerTheme))
          , ("deviceTheme", JEncode.string (colorThemeToString model.userinfo.deviceTheme))
        ]

postUserInfo : Model -> Cmd Msg
postUserInfo model = 
    Http.post
        { url = rootUrl ++ "postuserinfo/"
        , body = Http.jsonBody <| userInfoEncoder model
        , expect = Http.expectString PostUserInfo
        }

userInfoDecoder : JDecode.Decoder UserInfo  
userInfoDecoder = 
    JDecode.map5 UserInfo
        (JDecode.field "highscore" JDecode.int)
        (JDecode.field "avgPoints" JDecode.float)
        (JDecode.field "gamesPlayed" JDecode.int)
        (JDecode.field "playerTheme" decodeColorThemeType)
        (JDecode.field "deviceTheme" decodeColorThemeType)

decodeColorThemeType : JDecode.Decoder ColorTheme   
decodeColorThemeType = 
    JDecode.string |> JDecode.andThen (\colorThemeTypeString ->
        case colorThemeTypeString of 
            "1" -> JDecode.succeed Theme1 
            "2" -> JDecode.succeed Theme2 
            "3" -> JDecode.succeed Theme3 
            "4" -> JDecode.succeed Theme4 
            "5" -> JDecode.succeed Theme5 
            _ -> JDecode.succeed Theme5
    )

getUserInfo : Cmd Msg 
getUserInfo =  
    Http.get 
        { url = rootUrl ++ "getuserinfo/"
        , expect = Http.expectJson GetUserInfo userInfoDecoder
        }

--Get overall highscore from server
highscoreDecoder : JDecode.Decoder Highscore 
highscoreDecoder = 
    JDecode.map2 Highscore 
        (JDecode.field "username" JDecode.string)
        (JDecode.field "highscore" JDecode.int)


--Get Leaderboard from server
leaderBoardDecoder : JDecode.Decoder Ranking 
leaderBoardDecoder =
    JDecode.map5 Ranking 
        (JDecode.field "firstPlace" highscoreDecoder)
        (JDecode.field "secondPlace" highscoreDecoder)
        (JDecode.field "thirdPlace" highscoreDecoder)
        (JDecode.field "fourthPlace" highscoreDecoder)
        (JDecode.field "fifthPlace" highscoreDecoder)


getLeaderBoard : Cmd Msg 
getLeaderBoard = 
    Http.get 
        { url = rootUrl ++ "getleaderboard/"
        , expect = Http.expectJson GetLeaderBoard leaderBoardDecoder
        }

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
--<<Init>>
init : () -> Url.Url -> Key -> ( Model, Cmd Msg )
init flags url key = 
    let model = { screen = Login
                , error = ""
                , player1_pos = (-30,-10)
                , player2_pos = (30,-10) 
                , count = 0
                , jumpX = 1.5
                , bigPlayer = Player2
                , jumpingPlayer = None
                , gameEnd = False
                , points = 0
                , credentials = {username = "", password = ""}
                , userinfo= {highscore = 0, avgPoints = 0.0, gamesPlayed = 0, playerTheme = Theme1, deviceTheme = Theme1}
                , leaderBoard = { firstPlace = {username = "---------", highscore = 0}
                                , secondPlace ={username = "---------", highscore = 0}
                                , thirdPlace = {username = "---------", highscore = 0}
                                , fourthPlace = {username = "---------", highscore = 0}
                                , fifthPlace = {username = "---------", highscore = 0}}
                }   
    in ( model , randDecideSize) 

--<<Update>>
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model = case Debug.log "msg" msg of
        Tick time (keyToState,(arrowX,arrowY),(wasdX,wasdY)) -> 
            let player1_jumpState = 
                    case keyToState (Key "o") of 
                        JustDown ->  Jump 
                        Down -> Jump
                        _ ->  NotJump

                player2_jumpState =
                    case keyToState (Key "p") of 
                        JustDown -> Jump
                        Down -> Jump
                        _ -> NotJump

                restart = 
                    case keyToState Space of 
                        JustDown -> True 
                        _ -> False

                player1_jumpingModel = {model | jumpingPlayer = Player1--change jumpStatus to jump
                                                , jumpX = model.jumpX + 1.5
                                                , player1_pos = updatePos (model.player1_pos) (2.5, getProjectile model.jumpX model.bigPlayer model.jumpingPlayer )
                                                , player2_pos = updatePos (model.player2_pos) (-2.5, -10)
                                                , count = model.count + 1 }

                notJumpingModel = {model | jumpingPlayer = None
                                            , jumpX = 0
                                            , player1_pos = updatePos (model.player1_pos) (2.5, -10)
                                            , player2_pos = updatePos (model.player2_pos) (-2.5,-10) }

                player2_jumpingModel = {model | jumpingPlayer = Player2
                                                , jumpX = model.jumpX + 1.5
                                                , player1_pos = updatePos (model.player1_pos) (2.5,-10)
                                                , player2_pos = updatePos (model.player2_pos) (-2.5, getProjectile model.jumpX model.bigPlayer model.jumpingPlayer )
                                                , count = model.count + 1 }

                resetModel = {model | player1_pos = (-114,-10)
                                    , count = 0
                                    , jumpingPlayer = None 
                                    , jumpX = 0
                                    , player2_pos = (114,-10)
                                    , points = model.points + 1
                            }

            in --CASE 1) if game over and player presses spacebar to restart
                if model.screen == Login || model.screen == SignUp || model.screen == LeaderBoard then (model,Cmd.none)
                else if model.screen == Game Start  && restart == False then (model,Cmd.none)
                else if restart && (model.screen == Game End || model.screen == Game Start) then 
                    let oldUserInfo = model.userinfo 
                        newUserInfo = { oldUserInfo | gamesPlayed = model.userinfo.gamesPlayed + 1 }
                        newModel = { model | player1_pos = (-114,-10)
                                    , player2_pos = (114,-10) 
                                    , count = 0
                                    , jumpX = 1.5
                                    , bigPlayer = None
                                    , jumpingPlayer = None
                                    , screen = Game InProgress
                                    , gameEnd = False
                                    , points = 0
                                    , userinfo = newUserInfo }
                    in (newModel, randDecideSize)
                --CASE 2)if there's a collision, end game 
                else if isCollision model then 
                    let newHighscore = if model.points > model.userinfo.highscore then model.points else model.userinfo.highscore 
                        oldUserInfo = model.userinfo
                        newUserInfo= { oldUserInfo | highscore = newHighscore}
                        newModel = {model | player1_pos = model.player1_pos, player2_pos = model.player2_pos, screen = Game End, userinfo = newUserInfo, gameEnd=True }
                    in if model.gameEnd == True then
                            (model,Cmd.none)
                        else
                            (newModel, Cmd.batch[getLeaderBoard, postUserInfo newModel]) --sendHighscore model 
                
                --CASE 3) for 100 ticks, move players, after 100 ticks, reset to original position
                else if model.count < 100 then
                    --if player1 initialized jumping 
                    if (player1_jumpState == Jump) && (model.jumpingPlayer == None) then
                        (player1_jumpingModel, Cmd.none)
                    --if player1 is still in air 
                    else if model.jumpingPlayer == Player1 then 
                        -- if player 1 hit the ground; ie finished jumping
                        if (getProjectile model.jumpX model.bigPlayer model.jumpingPlayer ) <= -10 then 
                            (notJumpingModel, Cmd.none)
                        -- if player1 is still in air
                        else (player1_jumpingModel, Cmd.none)
                    --if player2 initialized jumping
                    else if (player2_jumpState == Jump) && model.jumpingPlayer == None then
                        (player2_jumpingModel, Cmd.none)
                    --if player2 is still in air
                    else if model.jumpingPlayer == Player2 then 
                        -- of player2 hits the ground
                        if (getProjectile model.jumpX model.bigPlayer model.jumpingPlayer ) <= -10 then 
                            (notJumpingModel, Cmd.none)
                    -- if player1 is still in air
                        else (player2_jumpingModel, Cmd.none)              
                    --if neither player1 nor player2 jumps
                    else
                        ({model | player1_pos = updatePos (model.player1_pos) (2.5,-10)
                                , player2_pos = updatePos (model.player2_pos) (-2.5,-10)
                                , count = model.count + 1
                                , screen = Game InProgress }
                        , Cmd.none)

                --CASE 4) if time == 2 seconds, reset to original position
                else (resetModel, Cmd.batch[randDecideSize, Cmd.none])
        
        MakeRequest req    -> (model, Cmd.none)
        UrlChange url      -> (model, Cmd.none)

        DecideBigPlayer player -> ({model | bigPlayer = player}, Cmd.none) 

        ChangeColorTheme button -> 
                let newTheme = 
                        case button of
                            ThemeUp -> changeThemeRight model.userinfo.deviceTheme
                            ThemeDown -> changeThemeLeft model.userinfo.deviceTheme
                            ThemeRight -> changeThemeRight model.userinfo.playerTheme
                            ThemeLeft -> changeThemeLeft model.userinfo.playerTheme
                in if member button [ThemeUp, ThemeDown] then
                        let oldUserInfo = model.userinfo
                            newUserInfo = {oldUserInfo | deviceTheme = newTheme}
                            newModel = {model | userinfo = newUserInfo}
                        in ({model | userinfo = newUserInfo}, postUserInfo newModel)
                    else 
                        let oldUserInfo = model.userinfo
                            newUserInfo = {oldUserInfo | playerTheme = newTheme}
                            newModel = {model | userinfo = newUserInfo}
                        in (newModel, postUserInfo newModel)

        --Screen:  LOGIN
        LoginPost -> (model, loginPost model) 

        LogoutPost -> (model, logoutPost)
        
        GotoSignUpScreen -> ({model | screen = SignUp, error = ""}, Cmd.none)

        --Screen: SignUp
        SignUpPost -> (model,signupPost model) 

        GoBack -> ({model | screen = Login, error = ""}, Cmd.none) 
        
        --Update username and password on user input
        Username newUsername -> 
            let
                oldCredentials = model.credentials
                newCredentials = { oldCredentials | username = newUsername}
            in
                ({model | credentials = newCredentials}, Cmd.none)

        Password newPassword ->
            let oldCredentials = model.credentials
                newCredentials = { oldCredentials | password = newPassword}
            in ({model | credentials = newCredentials}, Cmd.none)

        --Screen: Game 
        GotoLeaderBoardScreen ->
            if member model.screen [Game Start, Game End] then ({model | screen = LeaderBoard}, getLeaderBoard )
            else (model, Cmd.none)

        GoBackToGame ->
            if model.screen == LeaderBoard then ({model | screen = Game Start}, Cmd.none)
            else (model, Cmd.none)


        --SERVER RESPONSE
        --Userinfo
        PostUserInfo result ->
            case result of 
                Ok "UpdatedUserInfo" ->
                    ( model, Cmd.none) --why am i doing a get here???????? NOTE COME BACK LATER FIX
                Ok "UserIsNotLoggedIn" ->
                    ( {model | error = "User Is Not Logged In"}, Cmd.none)
                Ok _ -> 
                    (model, Cmd.none)
                Err error ->
                    ( handleError model error, Cmd.none )

        GetUserInfo result -> 
            case result of
                Ok newModel ->
                    ( { model | userinfo = newModel}, Cmd.none)
                Err error ->
                    ( handleError model error, Cmd.none )

        --LeaderBoard
        GetLeaderBoard result ->
            case result of 
                Ok newModel -> 
                    ( { model | leaderBoard = newModel}, getUserInfo)
                Err error ->    
                    ( handleError model error, Cmd.none)

        --User Authentication 
        GotLoginResponse result ->
            case result of
                Ok "LoginFailed" ->
                   ( { model | error = "Incorrect Username/Password"}, Cmd.none)
                Ok "LoggedIn" ->
                    ( { model | screen = Game Start, player1_pos = (-30,-10), player2_pos = (30,-10), error = "" }, getLeaderBoard)
                Ok _ -> 
                    (model, Cmd.none)
                Err error ->
                    ( handleError model error, Cmd.none )

        GotSignupResponse result ->
            case result of 
                Ok "SignupFail" ->  
                    ({ model | error = "Invalid Username/Password"}, Cmd.none)
                Ok "UserAlreadyExists" ->
                    ({ model | error = "User Already Exists! Try Again."}, Cmd.none)
                Ok _ ->
                    ( {model | screen = Game Start, player1_pos = (-30,-10), player2_pos = (30,-10), error = "" }, Cmd.none)
                Err error ->
                    ( handleError model error, Cmd.none )


        GotLogoutResponse result ->
            case result of 
                Ok "LoggedOut" ->
                    let
                        oldCredentials= model.credentials
                        newCredentials= { oldCredentials | username = "", password = ""}
                        oldUserInfo = model.userinfo 
                        newUserInfo = { oldUserInfo | highscore = 0, avgPoints = 0, gamesPlayed = 0, playerTheme = Theme1, deviceTheme = Theme1}
                    in
                        ({model | credentials = newCredentials, userinfo = newUserInfo, screen = Login, error = ""}, Cmd.none) --TODO: update logout post!!
                Ok _ -> ( {model | error = "something happened"}, Cmd.none)
                Err error ->
                    ( handleError model error, Cmd.none)

--error 
handleError : Model -> Http.Error -> Model
handleError model error =
    case error of
        Http.BadUrl url ->
            { model | error = "bad url: " ++ url }
        Http.Timeout ->
            { model | error = "timeout" }
        Http.NetworkError ->
            { model | error = "network error" }
        Http.BadStatus i ->
            { model | error = "bad status " ++ String.fromInt i }
        Http.BadBody body ->
            { model | error = "bad body " ++ body }


--<<View>>
view : Model -> { title : String, body : Collage Msg }
view model = 
    let title = "Crash!"
        body = collage 101 150 shapes
        shapes =
            case model.screen of
                Login -> 
                    [ html 50 20 (Html.input [Html.Attributes.style "width" "25px", Html.Attributes.style "height" "5px", Html.Attributes.style "font-size" "3pt", Html.Attributes.placeholder "Username", Events.onInput Username][]) |> move (0,35)
                    , html 50 20 (Html.input [Html.Attributes.style "width" "25px", Html.Attributes.style "height" "5px", Html.Attributes.style "font-size" "3pt", Html.Attributes.placeholder "Password", Html.Attributes.type_ "password", Events.onInput Password] []) |> move (0,20)
                    , loginTitle, userBox , passwordBox, loginButton, gotoSignUpButton, errorMessage
                    ]

                SignUp -> 
                    [ html 50 20 (Html.input [Html.Attributes.style "width" "25px", Html.Attributes.style "height" "5px", Html.Attributes.style "font-size" "3pt", Html.Attributes.placeholder "Username", Events.onInput Username] []) |> move (0,35)
                    , html 50 20 (Html.input [Html.Attributes.style "width" "25px", Html.Attributes.style "height" "5px", Html.Attributes.style "font-size" "3pt", Html.Attributes.placeholder "Password", Html.Attributes.type_ "password", Events.onInput Password] []) |> move (0,20)
                    , signUpTitle, userBox, passwordBox, signUpButton, goBackButton, errorMessage
                    ]

                Game _ -> [ screen, basicTexts, instructions, gameOver, overallHighscore, player1, player2, logoutButton, themeButtons, showLeaderBoardButton, goBackToGameButton ] 
                
                LeaderBoard -> [ screen, basicTexts, overallHighscore, logoutButton, themeButtons, showLeaderBoardButton, goBackToGameButton, leaderBoard ] 

        --Error Msg
        errorMessage = GraphicSVG.text model.error |> size 5 |> sansserif |> bold |> filled red |> move (-39,-25) 
        
        --Screen: LOGIN
        loginTitle = textOutline "Login" 12 |> move (-18,40)

        loginButton = group [rect 30 10 |> filled grey |> addOutline(solid 0.7) black ,textOutline "Login" 6 |> move (-8,-2)]
            |> move (-20,-13)
            |> scale 0.7
            |> notifyTap LoginPost

        userBox = group [rect 30 10.5 |> filled lightRed |> addOutline(solid 0.7) black , textOutline "Username" 5 |> move (-12,-2)]
            |> move (-20,22.7)

        passwordBox = group [rect 30 10.5 |> filled blue |> addOutline(solid 0.7) black ,textOutline "Password" 5 |> move (-12,-2)]
            |> move (-20,8)

        gotoSignUpButton = group [rect 30 10 |> filled grey |> addOutline(solid 0.7) black ,textOutline "Sign up" 6 |> move (-10,-2)] 
            |> move (15,-13)
            |> scale 0.7
            |> notifyTap GotoSignUpScreen

        --Screen: SIGNUP
        signUpTitle = textOutline "Sign Up" 12 |> move (-24,40)

        signUpButton = group [rect 30 10 |> filled grey |> addOutline(solid 0.7) black , textOutline "Sign up" 6 |> move (-10,-2)]
            |> move (15,-13)
            |> scale 0.7
            |> notifyTap SignUpPost
        
        goBackButton = group [rect 30 10 |> filled grey |> addOutline(solid 0.7) black ,textOutline "Go Back" 6 |> move (-12,-2)]
            |> move (-20,-13)
            |> scale 0.7
            |> notifyTap GoBack

        --Screen: GAME
        basicTexts = group [textOutline "Crash!" 10 |> move (-13,54)
                          , GraphicSVG.text ("Points: " ++ (String.fromInt model.points)) |> sansserif |> bold |> size 4 |> (if member model.screen [Game Start, LeaderBoard]  then filled blank else filled black) |> move (-7,47)
                          , textOutline ("User: " ++ model.credentials.username) 4 |> move (-46,-30)]

        instructions = group [GraphicSVG.text ("Instructions") |> sansserif |> bold |> underline |> size 5 |> (if model.screen == Game Start then filled black else filled blank) |> move (-13,40)
                         , GraphicSVG.text "-Press O to jump Player 1" |> sansserif |> bold  |> size 3 |> (if model.screen == Game Start then filled black else filled blank) |> move (-17,35)
                         , GraphicSVG.text ("-Press P to jump Player 2") |> sansserif |> bold  |> size 3 |> (if model.screen == Game Start then filled black else filled blank) |> move (-17,30)
                         , GraphicSVG.text ("-Big guy jumps over the small guy") |> sansserif |> bold |> size 3 |> (if model.screen == Game Start then filled black else filled blank) |> move (-22,25)     
                         , GraphicSVG.text ("Press Spacebar to Start!") |> sansserif |> bold |> size 5 |> (if model.screen == Game  Start then filled red else filled blank) |> move (-29,15)]
                         |> move (0,4)

        screen = group [ roundedRect 100 148 5 |> (filled (first (colorThemeToDeviceColor model.userinfo.deviceTheme))) |> addOutline (solid 1) black 
                       , square 100 |> filled (rgb 214 244 255) |> addOutline (solid 1) black |> move (0, 17)
                       , rect 100 20 |> filled (rgb 177 227 127) |> addOutline (solid 1) black |> move (0,-23.5)]
        
        themeButtons = group[ --UpButton
                              circle 4 |> (filled (second (colorThemeToDeviceColor model.userinfo.deviceTheme))) |> addOutline(solid 0.7) black |> move (28.5,-40) |> notifyTap (ChangeColorTheme ThemeUp)
                            , triangle 2 |> filled black |> rotate (3.14/2)|> move (28.5,-40) |> (notifyTap (ChangeColorTheme ThemeUp))
                             -- DownButton
                            , circle 4 |> (filled (second (colorThemeToDeviceColor model.userinfo.deviceTheme)))|> addOutline(solid 0.7) black |> move (28.5,-56) |> notifyTap (ChangeColorTheme ThemeDown)
                            , triangle 2 |> filled black |> rotate (3.14/2) |> mirrorY |> move (28.5,-56) |> notifyTap (ChangeColorTheme ThemeDown)
                             -- RightButton
                            ,  circle 4 |> (filled (second (colorThemeToDeviceColor model.userinfo.deviceTheme))) |> addOutline(solid 0.7) black |> move (36,-48) |> notifyTap (ChangeColorTheme ThemeRight)
                            , triangle 2 |> filled black |> move (36, -48) |> notifyTap (ChangeColorTheme ThemeRight)
                            -- LeftButton
                            , circle 4 |> (filled (second (colorThemeToDeviceColor model.userinfo.deviceTheme))) |> addOutline(solid 0.7) black  |> move (21,-48) |> notifyTap (ChangeColorTheme ThemeLeft)
                            , triangle 2 |> filled black |> mirrorX |> move (21,-48) |> notifyTap (ChangeColorTheme ThemeLeft)
                            ] |> move (6,0)

        showLeaderBoardButton = group [roundedRect 9 9 2 |> (filled (second (colorThemeToDeviceColor model.userinfo.deviceTheme))) |> addOutline (solid 0.7) black , textOutline "L" 8 |> move (-2.5,-2.5)]
                                        |> move (13,-45)
                                        |> notifyTap GotoLeaderBoardScreen

        overallHighscore = group [roundedRect 47 33 2 |> filled lightGrey |> addOutline (solid 0.7) black |> move (-24,-50)
                                , textOutline ("Overall Highscore: " ++ String.fromInt model.leaderBoard.firstPlace.highscore) 4 |> move (-45,-40)
                                , textOutline ("By User: " ++ model.leaderBoard.firstPlace.username) 3 |> move (-45,-45)
                                , textOutline ("Your highscore is: " ++ String.fromInt model.userinfo.highscore ) 3 |> move (-45,-52)
                                , textOutline ("# Games Played: " ++ String.fromInt model.userinfo.gamesPlayed) 3 |> move (-45, -57)
                                , textOutline ("Avg Points: " ++ String.fromFloat model.userinfo.avgPoints ) 3 |> move (-45, -62) ]
                                |> move (3,-3)

        gameOver = GraphicSVG.text ("Game Over! Press Spacebar to Restart!") |> sansserif |> bold |> size 5 |> (if model.screen == Game  End then filled red else filled blank) |> move (-46,35)

        logoutButton = group [roundedRect 30 10 2 |> filled (rgb 212 53 79) |> addOutline(solid 1) black , textOutline "Logout" 6 |> move (-10,-2)]
            |> move (41,-96)
            |> scale 0.7
            |> notifyTap LogoutPost

        --Player 1
        player1 = group [player1_body, player1_eye]
            |> move (model.player1_pos)

        player1_body = if model.bigPlayer == Player1 then
                            square 16 |> filled (first (colorThemeToPlayerColor model.userinfo.playerTheme)) |> addOutline (solid 1) black |> move (0.0,5.5)
                       else square 8 |> filled (first (colorThemeToPlayerColor model.userinfo.playerTheme)) |> addOutline (solid 1) black |> move(0.0,1.5)

        player1_eye = if model.bigPlayer == Player1 then
                            circle 1.5 |> filled white |> move (3,7) |> addOutline (solid 1) black
                      else circle 0.8 |> filled white |> move(1.7,2) |> addOutline(solid 0.7) black

        --Player 2
        player2 = group [player2_body, player2_eye]
            |> move (model.player2_pos)

        player2_body = if model.bigPlayer == Player2 then 
                            square 16 |> filled (second (colorThemeToPlayerColor model.userinfo.playerTheme)) |> addOutline (solid 1) black |> move (0.0,5.5)
                       else square 8 |> filled (second (colorThemeToPlayerColor model.userinfo.playerTheme)) |> addOutline (solid 1) black |> move(0.0,1.5)

        player2_eye = if model.bigPlayer == Player2 then 
                        rect 6 2 |> filled white |> addOutline (solid 1) black |> move (3.5,7.5) |> rotate 0.7
                      else rect 2.5 1 |> filled white |> addOutline (solid 0.5) black |> rotate (0.7) |> move (-1,2.5)


        --Screen: LEADERBOARD
        leaderBoard = group [ textOutline "Username" 6 |> move (-30,43), textOutline "Points" 6 |> move (12,43)
                            , textOutline ("1) " ++ model.leaderBoard.firstPlace.username) 6 |> move (-30,33), textOutline (String.fromInt model.leaderBoard.firstPlace.highscore) 6 |> move (20,33)
                            , textOutline ("2) " ++ model.leaderBoard.secondPlace.username) 6 |> move (-30,23), textOutline (String.fromInt model.leaderBoard.secondPlace.highscore) 6 |> move (20,23)
                            , textOutline ("3) " ++ model.leaderBoard.thirdPlace.username) 6 |> move (-30,13), textOutline (String.fromInt model.leaderBoard.thirdPlace.highscore) 6 |> move (20,13)
                            , textOutline ("4) " ++ model.leaderBoard.fourthPlace.username) 6 |> move (-30,3), textOutline (String.fromInt model.leaderBoard.fourthPlace.highscore) 6 |> move (20,3)
                            , textOutline ("5) " ++ model.leaderBoard.fifthPlace.username) 6 |> move (-30,-7), textOutline (String.fromInt model.leaderBoard.fifthPlace.highscore) 6 |> move (20,-7)
                             ]

        goBackToGameButton = group [roundedRect 9 9 2 |> (filled (second (colorThemeToDeviceColor model.userinfo.deviceTheme)))|> addOutline (solid 0.7) black
                                  , textOutline "B" 8 |> move (-3,-3)]
                                    |> move (13,-56)
                                    |> notifyTap GoBackToGame

    in { title = title , body = body }

--<<Other>>
subscriptions : Model -> Sub Msg
subscriptions model = Sub.none

main : AppWithTick () Model Msg
main = appWithTick Tick
       { init = init
       , update = update
       , view = view
       , subscriptions = subscriptions
       , onUrlRequest = MakeRequest
       , onUrlChange = UrlChange
       } 



