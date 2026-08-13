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
      updatedAt: Timestamp.now(),
    };

    await assertSucceeds(owner.doc(path).set(valid));
    await assertSucceeds(friend.doc(path).get());
    await assertFails(stranger.doc(path).get());
    await assertFails(friend.doc(path).update({ workoutCount: 2 }));
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
