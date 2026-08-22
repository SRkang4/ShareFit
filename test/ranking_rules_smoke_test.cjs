const fs = require('fs');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { Timestamp } = require('firebase/firestore');

async function main() {
  const testEnvironment = await initializeTestEnvironment({
    projectId: 'sharefit-ranking-rules-test',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });

  try {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await firestore.doc('users/owner/friends/friend').set({
        friendUid: 'friend',
        requestId: 'friend_owner',
      });
      await firestore.doc('users/friend/friends/owner').set({
        friendUid: 'owner',
        requestId: 'friend_owner',
      });
      await firestore.doc('users/pro-user').set({
        uid: 'pro-user',
        email: 'pro@example.com',
        name: 'Pro',
        friendCode: 'P0000001',
        isPro: true,
        friendCount: 0,
        profileCustomization: { titleId: 'none', themeId: 'default' },
      });
      await firestore.doc('publicProfiles/pro-user').set({
        uid: 'pro-user',
        name: 'Pro',
        friendCode: 'P0000001',
        active: true,
        profileTitleId: 'none',
        profileThemeId: 'default',
        updatedAt: Timestamp.now(),
      });
      await firestore.doc('users/free-user').set({
        uid: 'free-user',
        email: 'free@example.com',
        name: 'Free',
        friendCode: 'F0000001',
        isPro: false,
        friendCount: 0,
        profileCustomization: { titleId: 'none', themeId: 'default' },
      });
      await firestore.doc('publicProfiles/free-user').set({
        uid: 'free-user',
        name: 'Free',
        friendCode: 'F0000001',
        active: true,
        profileTitleId: 'none',
        profileThemeId: 'default',
        updatedAt: Timestamp.now(),
      });
      await firestore
        .doc('publicWorkoutStats/owner/days/2026-08-13')
        .set({
          uid: 'owner',
          dateKey: '2026-08-13',
          workoutCount: 1,
          durationSeconds: 600,
          updatedAt: Timestamp.now(),
        });
    });

    const owner = testEnvironment.authenticatedContext('owner').firestore();
    const friend = testEnvironment.authenticatedContext('friend').firestore();
    const stranger = testEnvironment
      .authenticatedContext('stranger')
      .firestore();
    const path = 'publicWorkoutStats/owner/days/2026-08-14';
    const valid = {
      uid: 'owner',
      dateKey: '2026-08-14',
      workoutCount: 1,
      durationSeconds: 1200,
      strengthVolumeKg: 2400,
      runningDistanceMeters: 0,
      updatedAt: Timestamp.now(),
    };

    const tokenPath = 'users/owner/fcmTokens/token-hash';
    await assertSucceeds(
      owner.doc(tokenPath).set({
        token: 'valid-fcm-token',
        platform: 'android',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      }),
    );
    await assertSucceeds(owner.doc(tokenPath).get());
    await assertFails(stranger.doc(tokenPath).get());
    await assertFails(
      stranger.doc('users/owner/fcmTokens/attacker').set({
        token: 'attacker-token',
        platform: 'android',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      }),
    );
    await assertFails(
      owner.doc('users/owner/fcmTokens/invalid').set({
        token: '',
        platform: 'unknown',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      }),
    );
    await assertFails(
      owner.doc('notificationCooldowns/owner/targets/friend').set({
        senderUid: 'owner',
        targetUid: 'friend',
        lastSentAt: Timestamp.now(),
      }),
    );

    await assertSucceeds(owner.doc(path).set(valid));
    await assertSucceeds(friend.doc(path).get());
    await assertFails(stranger.doc(path).get());
    await assertFails(friend.doc(path).update({ workoutCount: 2 }));
    await assertSucceeds(
      owner.doc(path).set({
        ...valid,
        workoutCount: 2,
        durationSeconds: 1800,
        strengthVolumeKg: 2400,
        runningDistanceMeters: 3000,
      }),
    );
    await assertFails(
      owner.doc(path).set({
        ...valid,
        workoutCount: 3,
        durationSeconds: 1800,
        strengthVolumeKg: 2400,
        runningDistanceMeters: -1,
      }),
    );

    const proUser = testEnvironment
      .authenticatedContext('pro-user')
      .firestore();
    const proBatch = proUser.batch();
    proBatch.update(proUser.doc('users/pro-user'), {
      profileCustomization: {
        titleId: 'runningLover',
        themeId: 'mint',
      },
    });
    proBatch.update(proUser.doc('publicProfiles/pro-user'), {
      profileTitleId: 'runningLover',
      profileThemeId: 'mint',
      updatedAt: Timestamp.now(),
    });
    await assertSucceeds(proBatch.commit());

    const freeUser = testEnvironment
      .authenticatedContext('free-user')
      .firestore();
    const freeBatch = freeUser.batch();
    freeBatch.update(freeUser.doc('users/free-user'), {
      profileCustomization: {
        titleId: 'consistent',
        themeId: 'pink',
      },
    });
    freeBatch.update(freeUser.doc('publicProfiles/free-user'), {
      profileTitleId: 'consistent',
      profileThemeId: 'pink',
      updatedAt: Timestamp.now(),
    });
    await assertFails(freeBatch.commit());

    await assertFails(
      proUser.doc('publicProfiles/pro-user').update({
        profileTitleId: 'shareFitPro',
        profileThemeId: 'yellow',
        updatedAt: Timestamp.now(),
      }),
    );

    const publicWorkoutPath =
      'publicWorkoutActivities/owner/days/2026-08-14/workouts/workout-1';
    const publicWorkout = {
      uid: 'owner',
      workoutId: 'workout-1',
      dateKey: '2026-08-14',
      type: 'strength',
      startedAt: Timestamp.now(),
      endedAt: Timestamp.now(),
      durationSeconds: 1200,
      photoUrl: null,
      photoCreatedAt: null,
      photoExpiresAt: null,
      strengthSummary: {
        bodyParts: ['가슴'],
        completedSetCount: 3,
        totalVolumeKg: 2400,
      },
      runningSummary: null,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    };
    await assertSucceeds(owner.doc(publicWorkoutPath).set(publicWorkout));
    await assertSucceeds(friend.doc(publicWorkoutPath).get());
    await assertFails(stranger.doc(publicWorkoutPath).get());
    await assertFails(
      friend.doc(publicWorkoutPath).update({ photoUrl: 'https://bad.example' }),
    );
    await assertSucceeds(
      owner.doc(publicWorkoutPath).update({
        photoUrl: 'https://example.com/photo.jpg',
        photoCreatedAt: Timestamp.now(),
        photoExpiresAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      }),
    );
    await assertSucceeds(
      owner.doc('publicWorkoutStats/owner/days/2026-08-13').set({
        uid: 'owner',
        dateKey: '2026-08-13',
        workoutCount: 2,
        durationSeconds: 1200,
        strengthVolumeKg: 1000,
        runningDistanceMeters: 0,
        updatedAt: Timestamp.now(),
      }),
    );
    await assertFails(
      owner.doc('publicWorkoutStats/owner/days/2026-08-15').set({
        ...valid,
        dateKey: '2026-08-15',
        durationSeconds: -1,
      }),
    );
  } finally {
    await testEnvironment.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
