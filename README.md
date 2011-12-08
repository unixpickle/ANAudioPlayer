ANAudioPlayer
=============

I made ANAudioPlayer in search of something new to learn. There are already many classes for playing back audio files in Objective-C, many holding more functionality than `ANAudioPlayer`. This project is really for those who want to learn about audio playback through the AudioToolbox framework. ANAudioPlayer is essentially a remake of Apple's Objective-C++ `AQPlayer` class. In my opinion, my implementation does look a bit more neat than Apple's, and it makes things easier to understand for those who are not C++ savvy.

ANAudioPlayer provides a simple interface for loading an audio file, playing it, and stopping playback. The basic usage of `ANAudioPlayer` is as follows:

    ANAudioPlayer * player;
    player = [[ANAudioPlayer alloc] initWithAudioFile:songFile];
    [player startPlaying];

Unfortunately, my implementation requires that ARC be enabled, which can cause several issues in playback situations. Mainly, you will want to avoid declaring an ANAudioPlayer as a local variable that will go out of scope before playback is complete. If this occurs, the `ANAudioPlayer` instance will be deallocated before playback completes, and will therefore most likely lead to a memory fault.

License
=======

This project is under no license, although I cannot make any promises as to its functionality. It is my belief that learning is important, as it was my intention when I created this project. If you are interested more in the functionality of this class rather than learning something from the code, I would suggest having a look at the `AVFoundation` framework.
