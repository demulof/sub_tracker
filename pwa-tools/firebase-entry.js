// 打包成 docs/vendor/firebase.js 的 Firebase 模組清單（只放 app 用到的函式，縮小檔案）。
// 重新打包：cd pwa-tools && npm install && npm run build
export { initializeApp } from 'firebase/app';
export {
  initializeAuth,
  indexedDBLocalPersistence,
  browserLocalPersistence,
  onAuthStateChanged,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
  sendPasswordResetEmail,
  sendEmailVerification,
  updateProfile,
  reauthenticateWithCredential,
  EmailAuthProvider,
  deleteUser,
  reload,
} from 'firebase/auth';
export {
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager,
  collection,
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  onSnapshot,
  getDocs,
  query,
  limit,
  writeBatch,
  Timestamp,
  serverTimestamp,
} from 'firebase/firestore';
