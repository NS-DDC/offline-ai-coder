'use strict';

const canvas = document.getElementById('omokBoard');
const ctx = canvas.getContext('2d');

const BOARD_SIZE = 15;
const PADDING = 32;
const CELL_SIZE = (canvas.width - PADDING * 2) / (BOARD_SIZE - 1);

let board = [];
let currentPlayer = 1;   // 1 = 흑(black), 2 = 백(white)
let gameOver = false;
let moveHistory = [];
let scores = { 1: 0, 2: 0 };
let winningLine = null;

// ─── 초기화 ───────────────────────────────────────────────────────────────────
function initBoard() {
    board = Array.from({ length: BOARD_SIZE }, () => Array(BOARD_SIZE).fill(0));
    currentPlayer = 1;
    gameOver = false;
    moveHistory = [];
    winningLine = null;
    updateStatus();
    updateActivePlayer();
    drawBoard();
}

// ─── 그리기 ───────────────────────────────────────────────────────────────────
function drawBoard() {
    // 바둑판 배경 (나무 질감)
    const bg = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
    bg.addColorStop(0,   '#dcb060');
    bg.addColorStop(0.5, '#c89840');
    bg.addColorStop(1,   '#b07828');
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // 보드 외곽 테두리
    ctx.strokeStyle = '#7a5c1e';
    ctx.lineWidth = 2;
    ctx.strokeRect(
        PADDING, PADDING,
        (BOARD_SIZE - 1) * CELL_SIZE,
        (BOARD_SIZE - 1) * CELL_SIZE
    );

    // 격자선
    ctx.strokeStyle = 'rgba(100, 70, 20, 0.7)';
    ctx.lineWidth = 0.8;
    for (let i = 0; i < BOARD_SIZE; i++) {
        const x = PADDING + i * CELL_SIZE;
        const y = PADDING + i * CELL_SIZE;

        ctx.beginPath();
        ctx.moveTo(x, PADDING);
        ctx.lineTo(x, PADDING + (BOARD_SIZE - 1) * CELL_SIZE);
        ctx.stroke();

        ctx.beginPath();
        ctx.moveTo(PADDING, y);
        ctx.lineTo(PADDING + (BOARD_SIZE - 1) * CELL_SIZE, y);
        ctx.stroke();
    }

    // 화점 (star points)
    const starPoints = [
        [3,3],[3,7],[3,11],
        [7,3],[7,7],[7,11],
        [11,3],[11,7],[11,11]
    ];
    ctx.fillStyle = 'rgba(80, 50, 10, 0.85)';
    for (const [r, c] of starPoints) {
        ctx.beginPath();
        ctx.arc(PADDING + c * CELL_SIZE, PADDING + r * CELL_SIZE, 4, 0, Math.PI * 2);
        ctx.fill();
    }

    // 돌 그리기
    for (let r = 0; r < BOARD_SIZE; r++) {
        for (let c = 0; c < BOARD_SIZE; c++) {
            if (board[r][c] !== 0) drawStone(r, c, board[r][c]);
        }
    }

    // 마지막 착수 표시
    if (moveHistory.length > 0) {
        const last = moveHistory[moveHistory.length - 1];
        const x = PADDING + last.col * CELL_SIZE;
        const y = PADDING + last.row * CELL_SIZE;
        const ms = CELL_SIZE * 0.22;
        ctx.strokeStyle = last.player === 1 ? 'rgba(255,80,80,0.9)' : 'rgba(60,100,255,0.9)';
        ctx.lineWidth = 2;
        ctx.strokeRect(x - ms, y - ms, ms * 2, ms * 2);
    }

    // 승리선 하이라이트
    if (winningLine && winningLine.length >= 2) {
        const s = winningLine[0];
        const e = winningLine[winningLine.length - 1];
        ctx.save();
        ctx.strokeStyle = 'rgba(255, 40, 40, 0.9)';
        ctx.lineWidth = 5;
        ctx.shadowColor = 'rgba(255, 40, 40, 1)';
        ctx.shadowBlur = 12;
        ctx.beginPath();
        ctx.moveTo(PADDING + s.col * CELL_SIZE, PADDING + s.row * CELL_SIZE);
        ctx.lineTo(PADDING + e.col * CELL_SIZE, PADDING + e.row * CELL_SIZE);
        ctx.stroke();
        ctx.restore();
    }
}

function drawStone(row, col, player) {
    const x = PADDING + col * CELL_SIZE;
    const y = PADDING + row * CELL_SIZE;
    const r = CELL_SIZE * 0.44;

    let grad;
    if (player === 1) {
        grad = ctx.createRadialGradient(x - r * 0.3, y - r * 0.35, r * 0.05, x, y, r);
        grad.addColorStop(0, '#888');
        grad.addColorStop(0.35, '#333');
        grad.addColorStop(1, '#000');
    } else {
        grad = ctx.createRadialGradient(x - r * 0.3, y - r * 0.35, r * 0.05, x, y, r);
        grad.addColorStop(0, '#ffffff');
        grad.addColorStop(0.55, '#e8e8e8');
        grad.addColorStop(1, '#b0b0b0');
    }

    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = grad;
    ctx.fill();

    ctx.strokeStyle = player === 1 ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.25)';
    ctx.lineWidth = 0.8;
    ctx.stroke();
}

function drawHoverStone(row, col) {
    const x = PADDING + col * CELL_SIZE;
    const y = PADDING + row * CELL_SIZE;
    const r = CELL_SIZE * 0.44;
    ctx.globalAlpha = 0.38;
    ctx.fillStyle = currentPlayer === 1 ? '#000' : '#fff';
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
}

// ─── 이벤트 ───────────────────────────────────────────────────────────────────
function toBoardCoord(clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width  / rect.width;
    const scaleY = canvas.height / rect.height;
    const col = Math.round(((clientX - rect.left) * scaleX - PADDING) / CELL_SIZE);
    const row = Math.round(((clientY - rect.top)  * scaleY - PADDING) / CELL_SIZE);
    return { row, col };
}

canvas.addEventListener('click', (e) => {
    if (gameOver) return;
    const { row, col } = toBoardCoord(e.clientX, e.clientY);
    if (row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE) return;
    if (board[row][col] !== 0) return;

    board[row][col] = currentPlayer;
    moveHistory.push({ row, col, player: currentPlayer });

    const win = checkWin(row, col, currentPlayer);
    if (win) {
        winningLine = win;
        gameOver = true;
        scores[currentPlayer]++;
        drawBoard();
        updateScores();
        setTimeout(() => showWinModal(currentPlayer), 350);
        return;
    }

    if (moveHistory.length === BOARD_SIZE * BOARD_SIZE) {
        gameOver = true;
        drawBoard();
        updateStatus('무승부! 판이 꽉 찼습니다');
        return;
    }

    currentPlayer = currentPlayer === 1 ? 2 : 1;
    updateStatus();
    updateActivePlayer();
    drawBoard();
});

canvas.addEventListener('mousemove', (e) => {
    if (gameOver) return;
    const { row, col } = toBoardCoord(e.clientX, e.clientY);
    drawBoard();
    if (row >= 0 && row < BOARD_SIZE && col >= 0 && col < BOARD_SIZE && board[row][col] === 0) {
        drawHoverStone(row, col);
    }
});

canvas.addEventListener('mouseleave', () => drawBoard());

// 터치 지원
canvas.addEventListener('touchstart', (e) => {
    e.preventDefault();
    if (gameOver) return;
    const touch = e.touches[0];
    const { row, col } = toBoardCoord(touch.clientX, touch.clientY);
    if (row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE) return;
    if (board[row][col] !== 0) return;

    board[row][col] = currentPlayer;
    moveHistory.push({ row, col, player: currentPlayer });

    const win = checkWin(row, col, currentPlayer);
    if (win) {
        winningLine = win;
        gameOver = true;
        scores[currentPlayer]++;
        drawBoard();
        updateScores();
        setTimeout(() => showWinModal(currentPlayer), 350);
        return;
    }

    if (moveHistory.length === BOARD_SIZE * BOARD_SIZE) {
        gameOver = true;
        drawBoard();
        updateStatus('무승부! 판이 꽉 찼습니다');
        return;
    }

    currentPlayer = currentPlayer === 1 ? 2 : 1;
    updateStatus();
    updateActivePlayer();
    drawBoard();
}, { passive: false });

// ─── 승리 판정 ────────────────────────────────────────────────────────────────
function checkWin(row, col, player) {
    const directions = [[0,1],[1,0],[1,1],[1,-1]];
    for (const [dr, dc] of directions) {
        const line = buildLine(row, col, player, dr, dc);
        if (line.length >= 5) return line;
    }
    return null;
}

function buildLine(row, col, player, dr, dc) {
    const line = [{ row, col }];
    for (let i = 1; i <= 4; i++) {
        const r = row + dr * i, c = col + dc * i;
        if (r < 0 || r >= BOARD_SIZE || c < 0 || c >= BOARD_SIZE || board[r][c] !== player) break;
        line.push({ row: r, col: c });
    }
    for (let i = 1; i <= 4; i++) {
        const r = row - dr * i, c = col - dc * i;
        if (r < 0 || r >= BOARD_SIZE || c < 0 || c >= BOARD_SIZE || board[r][c] !== player) break;
        line.unshift({ row: r, col: c });
    }
    return line;
}

// ─── UI 업데이트 ──────────────────────────────────────────────────────────────
function updateStatus(msg) {
    const el = document.getElementById('status-message');
    el.textContent = msg ?? (currentPlayer === 1 ? '⚫ 흑의 차례입니다' : '⚪ 백의 차례입니다');
}

function updateActivePlayer() {
    document.getElementById('player1-info').classList.toggle('active', currentPlayer === 1);
    document.getElementById('player2-info').classList.toggle('active', currentPlayer === 2);
}

function updateScores() {
    document.getElementById('score-black').textContent = scores[1];
    document.getElementById('score-white').textContent = scores[2];
}

function showWinModal(player) {
    document.getElementById('winStone').className = 'win-stone ' + (player === 1 ? 'black' : 'white');
    document.getElementById('winMessage').textContent  = player === 1 ? '🎉 흑 승리!' : '🎉 백 승리!';
    document.getElementById('winSubMessage').textContent = `플레이어 ${player}이(가) 5목을 완성했습니다!`;
    document.getElementById('winModal').classList.remove('hidden');
}

// ─── 버튼 ─────────────────────────────────────────────────────────────────────
document.getElementById('resetBtn').addEventListener('click', () => {
    document.getElementById('winModal').classList.add('hidden');
    initBoard();
});

document.getElementById('playAgainBtn').addEventListener('click', () => {
    document.getElementById('winModal').classList.add('hidden');
    initBoard();
});

document.getElementById('undoBtn').addEventListener('click', () => {
    if (moveHistory.length === 0 || gameOver) return;
    const last = moveHistory.pop();
    board[last.row][last.col] = 0;
    currentPlayer = last.player;
    updateStatus();
    updateActivePlayer();
    drawBoard();
});

// ─── 시작 ─────────────────────────────────────────────────────────────────────
initBoard();
