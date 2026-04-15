[![Codacy Badge](https://api.codacy.com/project/badge/Grade/8d4f552a98dc440a9aed7e929e9f7dd8)](https://app.codacy.com/gh/qx1ls-dr/DICE?utm_source=github.com&utm_medium=referral&utm_content=qx1ls-dr/DICE&utm_campaign=Badge_Grade)
[![Contributors](https://img.shields.io/github/contributors/qx1ls-dr/DICE.svg?style=for-the-badge)](https://github.com/qx1ls-dr/DICE/graphs/contributors)
[![Forks](https://img.shields.io/github/forks/qx1ls-dr/DICE.svg?style=for-the-badge)](https://github.com/qx1ls-dr/DICE/network/members)
[![Stargazers](https://img.shields.io/github/stars/qx1ls-dr/DICE.svg?style=for-the-badge)](https://github.com/qx1ls-dr/DICE/stargazers)
[![Issues](https://img.shields.io/github/issues/qx1ls-dr/DICE.svg?style=for-the-badge)](https://github.com/qx1ls-dr/DICE/issues)

[![License](https://img.shields.io/github/license/qx1ls-dr/DICE.svg?style=for-the-badge)](https://github.com/qx1ls-dr/DICE/blob/main/LICENSE)

![GitHub last commit](https://img.shields.io/github/last-commit/qx1ls-dr/DICE?style=for-the-badge)
![GitHub issues](https://img.shields.io/github/issues/qx1ls-dr/DICE?style=for-the-badge)
![GitHub pull requests](https://img.shields.io/github/issues-pr/qx1ls-dr/DICE?style=for-the-badge)

![CI](https://img.shields.io/github/actions/workflow/status/qx1ls-dr/DICE/ci-checks.yml?style=for-the-badge)
![Build](https://img.shields.io/github/actions/workflow/status/qx1ls-dr/DICE/cmake-single-platform.yml?style=for-the-badge)
![CodeQL](https://img.shields.io/github/actions/workflow/status/qx1ls-dr/DICE/codeql.yml?style=for-the-badge)

[![CodeFactor](https://img.shields.io/codefactor/grade/github/qx1ls-dr/DICE?style=for-the-badge)](https://www.codefactor.io/repository/github/qx1ls-dr/DICE)
[![Codacy Badge](https://img.shields.io/codacy/grade/DICE?style=for-the-badge)](https://app.codacy.com/gh/qx1ls-dr/DICE)


<br />
<div align="center">
  <h3 align="center">DICE</h3>

  <p align="center">
    Брось игральный кубик и создай настольную игру своей мечты
    <br />
    &middot;
    <a href="https://github.com/qx1ls-dr/DICE/issues/new?labels=bug&template=bug-report---.md">Написать о баге</a>
    &middot;
    <a href="https://github.com/qx1ls-dr/DICE/issues/new?labels=enhancement&template=feature-request---.md">Предложить фичу</a>
    &middot;
  </p>
</div>


##  О проекте

DICE - это комплексный инструмент разработки настольных 2D-игр, написанный на С++. Система строится на принципе отделения игровой логики от графического представления, что позволяет пользователю создавать новые игры через конфигурационные файлы без пересборки всего приложения.

## MVP

- Загрузка 2D-сцены из JSON.
- Рендеринг слоев.
- Перетаскивание одной фишки мышью.
- Ограничение перемещения фишки границами поля
- Базовая система триггеров для простейших игр.
- Взаимодействие с 2D компонентами: бросок кубика, перемещение фише


### Зависимости

В нашем проекте использовались:


[![SFML](https://img.shields.io/badge/SFML-Game%20Framework-8CC445?style=for-the-badge&logo=cplusplus)](https://www.sfml-dev.org/documentation/)

[![Lua](https://img.shields.io/badge/Lua-5.3-2C2D72?style=for-the-badge&logo=lua)](https://www.lua.org/manual/5.3/)

[![Dear ImGui](https://img.shields.io/badge/Dear%20ImGui-UI%20Library-1E1E1E?style=for-the-badge&logo=github)](https://github.com/ocornut/imgui)

[![nlohmann/json](https://img.shields.io/badge/nlohmann%2Fjson-JSON%20for%20C%2B%2B-000000?style=for-the-badge&logo=json)](https://json.nlohmann.me/)

[![sol2](https://img.shields.io/badge/sol2-Lua%20Bindings-000000?style=for-the-badge&logo=lua)](https://sol2.readthedocs.io/)


## Установка

1. Склонируйте репозиторий
   ```sh
   git clone https://github.com/qx1ls-dr/DICE.git
   ```
2. Перейдите в каталог DICE и пропишите
   ```sh
   cmake . -B build
   cd build
   make
   ```
4. Запустите приложение
   ```sh
    ./dice
   ```

## Скриншоты и демо-видео

_TODO_

## Создание объектов, скриптов и т.д.

_TODO_

## Лицензия

Проект находится под MIT License. См. "LICENSE".


## Связаться

 - [Artur Yumashev](https://github.com/Ariumashev) 
 - [Leonid Diakov](https://github.com/qx1ls-dr)
 - [Yaroslav Ilyin](https://github.com/ilinyar2007-bit)

[![Arthur](https://img.shields.io/badge/Arthur-@STDWRK-2CA5E0?style=for-the-badge&logo=telegram)](https://t.me/StdWrk)
[![Leonid](https://img.shields.io/badge/Leonid-@xQyll1-3DDC84?style=for-the-badge&logo=telegram)](https://t.me/@xQyll1)
[![Yaroslav](https://img.shields.io/badge/Yaroslav-@Krudsoadayu-F59E0B?style=for-the-badge&logo=telegram)](https://t.me/@Krudsoadayu)

