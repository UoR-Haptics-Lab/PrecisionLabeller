function totalReset()
    delete(timerfindall);
    close(findall(0, 'Type', 'figure'));
    evalin('caller', 'clearvars');
end
